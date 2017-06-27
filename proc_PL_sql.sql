CREATE OR REPLACE PROCEDURE p_final_mv2 IS
  CURSOR c_sol_mv IS
    SELECT     *
          FROM mv_pro_pen
         WHERE estado =
                   2 -- Estados (1) Proceso VM  (2) SC  (3) En proceso (4) Error 
      ORDER BY num_sol
    FOR UPDATE NOWAIT;

  CURSOR c_mov_vm(p_ent VARCHAR2, p_fon VARCHAR2, p_fec DATE, p_fec_ant DATE) IS
    SELECT *
      FROM mv_mov_val
     WHERE cod_ent = p_ent AND cod_fon = p_fon AND fec_dat = p_fec
           AND cod_ref IN (SELECT cod_ref
                             FROM mv_mov_val
                            WHERE cod_ent = p_ent AND cod_fon = p_fon
                                  AND fec_dat = p_fec
                           MINUS
                           SELECT cod_ref
                             FROM mv_mov_val
                            WHERE cod_ent = p_ent AND cod_fon = p_fon
                                  AND fec_dat = p_fec_ant);

  v_cod_ent mv_pro_pen.cod_ent%TYPE;
  v_cod_fon mv_pro_pen.cod_fon%TYPE;
  v_fec_dat mv_pro_pen.fec_dat%TYPE;
  v_cod_ref mv_pro_pen.cod_ref%TYPE;
  v_estado mv_pro_pen.estado%TYPE;
  v_num_sol mv_pro_pen.num_sol%TYPE;
  v_tot_pro NUMBER := 0; --total de procesos en estado 2 (ejecutándose)
  v_tot_eje NUMBER := 14; --máximo de validaciones simultáneas
  numerr NUMBER;
  v_registros NUMBER;
  menerr VARCHAR2(500);
  v_men VARCHAR2(500);
  v_fec_ant DATE;
  v_env_ala VARCHAR2(10);
  v_en_proceso VARCHAR2(1);
  gv_pro_pre VARCHAR2(2);

  PROCEDURE p_env_alarma(p_ent VARCHAR2, p_fon VARCHAR2, p_fec DATE) IS
    -- p_tip_cur U usuario, M mensaje
    CURSOR c_dat(p_tip_cur VARCHAR2) IS
      SELECT DISTINCT DECODE(p_tip_cur, 'U', a.usu_env, NULL) usu_env,
                      DECODE(p_tip_cur, 'U', b.abr_ent, NULL) abr_ent,
                      DECODE(
                        p_tip_cur, 'M', b.abr_ent
                                        || DECODE(
                                             a.cod_fon, NULL, ' ',
                                             ' fondo ' || a.cod_fon)
                                        || ' Incump. ' || c.des_cod || ' el '
                                        || TO_CHAR(a.fec_dat) || '.', NULL) mensaje
                 FROM mv_ala_inv a, tg_ent b, tg_cod_gen c
                WHERE a.cod_ent = p_ent
                      AND (a.cod_fon = p_fon OR a.cod_fon IS NULL)
                      AND a.fec_dat = p_fec AND a.fec_lec IS NULL
                      AND b.cod_ent = a.cod_ent AND a.cod_alarma NOT LIKE
                                                                         '%R'
                      AND c.cod_tab = 'ALA_INV' AND c.cod_gen = a.cod_alarma
      UNION
      SELECT DISTINCT DECODE(p_tip_cur, 'U', a.usu_env, NULL),
                      DECODE(p_tip_cur, 'U', b.abr_ent, NULL), --a.usu_env, b.abr_ent,
                      DECODE(
                        p_tip_cur, 'M', b.abr_ent
                                        || DECODE(
                                             a.cod_fon, NULL, ' ',
                                             ' fondo ' || a.cod_fon)
                                        || ' Incump. ' || c.des_cod || ' el '
                                        || TO_CHAR(a.fec_dat)
                                        || '. (Reincidencia)', NULL) mensaje
                 FROM mv_ala_inv a, tg_ent b, tg_cod_gen c
                WHERE a.cod_ent = p_ent
                      AND (a.cod_fon = p_fon OR a.cod_fon IS NULL)
                      AND a.fec_dat = p_fec AND a.fec_lec IS NULL
                      AND b.cod_ent = a.cod_ent AND a.cod_alarma LIKE '%R'
                      AND c.cod_tab = 'ALA_INV'
                      AND c.cod_gen = SUBSTR(a.cod_alarma, 1, 2);

    v_mess VARCHAR2(2500);
    v_correo VARCHAR2(300) := NULL;
    v_mail_princ VARCHAR2(300) := NULL;
    v_otr_mail VARCHAR2(3000) := NULL;
    v_titulo VARCHAR2(300);
    v_usu VARCHAR2(30) := 'XXXX';
    v_proc VARCHAR2(1) := 'N';
  BEGIN
    FOR c IN c_dat('U') LOOP
      SELECT LOWER(email)
        INTO v_correo
        FROM tg_usr
       WHERE cod_usr = c.usu_env;
      IF v_mail_princ IS NULL THEN
        v_titulo := 'Atención. Exceso de Límites en ' || c.abr_ent;
        IF v_correo IS NOT NULL AND INSTR(v_correo, '@') > 0 THEN
          v_mail_princ := v_correo;
        END IF;
      ELSE
        IF v_correo IS NOT NULL AND INSTR(v_correo, '@') > 0 THEN
          IF v_otr_mail IS NOT NULL THEN
            v_otr_mail := v_otr_mail || ';';
          END IF;
          v_otr_mail := NVL(v_otr_mail, '') || v_correo;
        END IF;
      END IF;
    END LOOP;
    FOR c IN c_dat('M') LOOP
      v_mess := NVL(v_mess, '') || c.mensaje || ' ' || CHR(10) || CHR(13);
    END LOOP;
    -- Aqui se envia el correo que no sse ha enviado por
    -- el funcionamiento del cursor
    IF v_mess IS NOT NULL THEN
      v_mess := NVL(v_mess, '')|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					          '** Tildes omitidas por el generador de correos **';		
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', v_mail_princ,
          v_otr_mail || ';oreamunoae@supen.fi.cr;vargasqg@supen.fi.cr;rojasvi@supen.fi.cr',
          v_titulo, v_mess);
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo '|| v_titulo || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;
    END IF;
  END;

  PROCEDURE p_env_correo(p_ent VARCHAR2, p_fon VARCHAR2, p_fec DATE,
    p_tit VARCHAR2, p_mess VARCHAR2) IS
    CURSOR c_dat(p_depto VARCHAR2) IS
      SELECT usr1_inv usu_env
        FROM tg_ent
       WHERE cod_ent = p_ent
      UNION
      SELECT usr2_inv usu_env
        FROM tg_ent
       WHERE cod_ent = p_ent
      UNION
      SELECT DISTINCT cod_usuario usu_env
                 FROM tg_grup_usua a, tg_usr b
                WHERE (a.cod_grupo LIKE 'SUP%'
                                        || DECODE(
                                             p_depto, 'O', 'INV', 'F', 'FON',
                                             'NO PROC')
                                        || '%')
                      AND a.cod_usuario = b.cod_usr
                      AND (p_depto = 'X' OR b.tip_dep = p_depto);

    --v_mess         VARCHAR2 (2500);
    v_correo VARCHAR2(300) := NULL;
    v_mail_princ VARCHAR2(300) := NULL;
    v_otr_mail VARCHAR2(3000) := NULL;
    v_titulo VARCHAR2(300);
    v_usu VARCHAR2(30) := 'XXXX';
    v_proc VARCHAR2(1) := 'N';
    v_depto VARCHAR2(1) := 'N';
  BEGIN
    IF p_ent LIKE 'A%' THEN
      v_depto := 'O';
    ELSE
      v_depto := 'F';
    END IF;
    FOR c IN c_dat(v_depto) LOOP
      SELECT LOWER(email)
        INTO v_correo
        FROM tg_usr
       WHERE cod_usr = c.usu_env;
      IF v_mail_princ IS NULL THEN
        v_titulo := p_tit;
        --'Atención. Exceso de Límites en '|| c.abr_ent;

        IF v_correo IS NOT NULL AND INSTR(v_correo, '@') > 0 THEN
          v_mail_princ := v_correo;
        END IF;
      ELSE
        IF v_correo IS NOT NULL AND INSTR(v_correo, '@') > 0 THEN
          IF v_otr_mail IS NOT NULL THEN
            v_otr_mail := v_otr_mail || ';';
          END IF;
          v_otr_mail := NVL(v_otr_mail, '') || v_correo;
        END IF;
      END IF;
    END LOOP;
    -- Aqui se envia el correo que no sse ha enviado por
    -- el funcionamiento del cursor
    IF p_mess IS NOT NULL THEN
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', v_mail_princ,
          v_otr_mail || ';oreamunoae@supen.fi.cr;vargasqg@supen.fi.cr;rojasvi@supen.fi.cr',
          v_titulo, p_mess);
					--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||'** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo '|| v_titulo || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;
    END IF;
  END;

  PROCEDURE rev_datos IS
    CURSOR c_dat IS
      SELECT   cod_ent, cod_fon, fec_dat, num_sol, ROWID lin
          FROM mv_pro_pen
         WHERE estado = 1
      ORDER BY num_sol;

    v_cod_rep VARCHAR2(5);
    v_cod_pro VARCHAR2(5);
    v_cod_fon VARCHAR2(5);
    v_reg INTEGER;
  BEGIN
    FOR d IN c_dat LOOP
      IF SUBSTR(d.cod_ent, 1, 1) = 'E' THEN
        v_cod_rep := 'SF';
        v_cod_pro := '73';
        v_cod_fon := d.cod_fon; --'94';
      ELSE
        v_cod_rep := 'SC';
        v_cod_pro := '03';
        v_cod_fon := d.cod_fon;
      END IF;
      SELECT COUNT(1)
        INTO v_reg
        FROM tg_bit
       WHERE cod_ent = d.cod_ent AND cod_fon = v_cod_fon
             AND fec_dat >= d.fec_dat AND cod_pro = v_cod_pro
             AND cod_rep = v_cod_rep AND fin = 3;
      IF NVL(v_reg, 0) > 0 THEN
        UPDATE mv_pro_pen
           SET estado = 2
         WHERE ROWID = d.lin;
        COMMIT;
      END IF;
    END LOOP;
  END;

  PROCEDURE p_calc_ppe(p_ent IN VARCHAR2, p_fon IN VARCHAR2, p_fec IN DATE) IS
    v_ppe NUMBER;
  BEGIN
    SELECT (SUM(estim_sup) / SUM(val_mer)) * 100
      INTO v_ppe
      FROM mv_mov_val
     WHERE cod_ent = p_ent AND cod_fon = p_fon AND fec_dat = p_fec;

    BEGIN
      INSERT INTO ir_perd
           VALUES (p_ent, p_fon, p_fec, NULL, NVL(v_ppe, 0));
    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        UPDATE ir_perd
           SET por_perd = NVL(v_ppe, 0)
         WHERE cod_ent = p_ent AND cod_fon = p_fon AND fec_dat = p_fec;
    END;
  END;

  PROCEDURE p_emis_venc IS
    
-- declare
    CURSOR c_dat(p_pais IN VARCHAR2, p_fec IN DATE) IS
      SELECT DISTINCT a.cod_emi, a.cod_ins, a.cod_isin, fec_vig_has
                 FROM tg_emi_aut a, tg_emi_cal b
                WHERE a.est_emi <> 'N' --and a.cod_nac_neg <> p_pais
                AND a.califica = 'S' AND b.llave = a.llave
                AND b.fec_vig_has between add_months(p_fec,-1) and p_fec 
								and not exists (select 1 from tg_emi_cal b1
								                where b1.llave = b.llave
																and b1.fec_vig_has > p_fec)
      UNION
      SELECT DISTINCT a.cod_emi, 'EMISOR' cod_ins, '' cod_isin, fec_vig_has
                 FROM tg_emi a, tg_emisor_cal b
                WHERE b.cod_emi = a.cod_emi 
                AND b.fec_vig_has between add_months(p_fec,-1) and p_fec 
								and not exists (select 1 from tg_emisor_cal b1
								                where b1.cod_emi = b.cod_emi
																and b1.fec_vig_has > p_fec);

/*		
      SELECT DISTINCT a.cod_emi, a.cod_ins, a.cod_isin
                 FROM tg_emi_aut a, tg_emi_cal b
                WHERE a.est_emi <> 'N' --and a.cod_nac_neg <> p_pais
                                       AND a.califica = 'S' AND b.llave =
                                                                      a.llave
                      AND b.fec_vig_has = p_fec
      UNION
      SELECT DISTINCT a.cod_emi, 'EMISOR' cod_ins, '' cod_isin
                 FROM tg_emi a, tg_emisor_cal b
                WHERE b.cod_emi = a.cod_emi AND b.fec_vig_has = p_fec;
*/
    CURSOR c_usr IS
      SELECT a.cod_usuario, LOWER(b.email) email
        FROM tg_grup_usua a, tg_usr b
       WHERE a.cod_grupo = 'MNT_INVER' AND b.cod_usr = a.cod_usuario and activo = 'S';

    v_pais VARCHAR2(5);
    v_fec DATE;
    v_mess VARCHAR2(5000) := null;
    v_mail_princ VARCHAR2(300) := NULL;
    v_otr_mail VARCHAR2(3000) := NULL;
    v_titulo VARCHAR2(300);
  BEGIN
	
	 update mp_vp_dia
   set for_cal = for_cal - 2
   where fec_vp between add_months(trunc(sysdate),-2) and trunc(sysdate) 
   and for_cal > 1; 
	 if sql%rowcount > 0 then
  	 commit;
		 	 enviar_correo(
              'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen',
              'oreamunoae@supen.fi.cr;vargasqg@supen.fi.cr;rojasvi@supen.fi.cr',
              'Actualizó vector de precios', 'Actualizó vector de precios');
   end if;							

	 
    BEGIN
      SELECT val_par
        INTO v_pais
        FROM tg_par_gen
       WHERE cod_par = 'PAISP';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_pais := '188';
    END;

    BEGIN
      SELECT TO_DATE(val_par, 'dd-mm-yyyy')
        INTO v_fec
        FROM tg_par_gen
       WHERE cod_par = 'FECAVI';
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_fec := TRUNC(SYSDATE);
    END; 
	 		
    IF v_fec <> TRUNC(SYSDATE) THEN
      v_fec := v_fec + 1;
      FOR c IN c_dat(v_pais, v_fec) LOOP
			  --dbms_output.put_line(c.cod_emi || '-' || c.cod_ins|| ' Isin ' || c.cod_isin);	
				if v_mess is null then
				   v_mess := 'Emisión ' || c.cod_emi || '-' || c.cod_ins || ' Isin ' || c.cod_isin || ' venció el ' || to_char(c.fec_vig_has) || CHR(10) || CHR(13);
				else
				  if length(v_mess) + length('Emisión ' || c.cod_emi || '-' || c.cod_ins || ' Isin ' || c.cod_isin || ' venció el ' || to_char(c.fec_vig_has) || CHR(10) || CHR(13)) < 4900 then 
            v_mess := NVL(v_mess, '') || 'Emisión ' || c.cod_emi || '-' || c.cod_ins || ' Isin ' || c.cod_isin || ' venció el ' || to_char(c.fec_vig_has) || CHR(10) || CHR(13);
				  else
				    exit;
  				end if;
				end if;
      END LOOP;
--dbms_output.put_line('emi venc paso 2');			
      IF v_mess IS NOT NULL THEN
        v_titulo :=
            'Atención. Existen calificaciones de instrumentos y emisores vencidas o por vencer'; --por vencer el '
            --|| TO_CHAR(v_fec);
        FOR d IN c_usr LOOP
          IF  d.email IS NOT NULL AND INSTR(d.email, '@') > 0 THEN
            IF v_mail_princ IS NULL THEN
              v_mail_princ := d.email;
            ELSE
              IF v_otr_mail IS NOT NULL THEN
                v_otr_mail := v_otr_mail || ';';
              END IF;
              v_otr_mail := NVL(v_otr_mail, '') || d.email;
            END IF;
          END IF;
        END LOOP;
        IF v_mail_princ IS NOT NULL THEN
				  --v_mess := NVL(v_mess, '')|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					--          '** Tildes omitidas por el generador de correos **';
          BEGIN
            enviar_correo(
              'supen_mensajeria@supen.fi.cr', v_mail_princ,
              v_otr_mail || ';oreamunoae@supen.fi.cr;vargasqg@supen.fi.cr;rojasvi@supen.fi.cr',
              v_titulo, v_mess);
          EXCEPTION
            WHEN OTHERS THEN
              INSERT INTO eduardo
                   VALUES ('Error enviando correo '|| v_titulo || ' '
                           || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
          END;
        END IF;
      END IF;
			v_mess := null;
      -- Vencidos
      FOR c IN c_dat(v_pais, v_fec - 1) LOOP
			  if v_mess is null then
				   v_mess := 'Emisión ' || c.cod_emi || '-' || c.cod_ins || ' Isin ' || c.cod_isin || ' venció el ' || to_char(c.fec_vig_has) || CHR(10) || CHR(13);
				else
				  if length(v_mess) + length('Emisión ' || c.cod_emi || '-' || c.cod_ins || ' Isin ' || c.cod_isin || ' venció el ' || to_char(c.fec_vig_has) || CHR(10) || CHR(13)) < 4900 then 
            v_mess := v_mess || 'Emisión ' || c.cod_emi || '-' || c.cod_ins || ' Isin ' || c.cod_isin || ' venció el ' || to_char(c.fec_vig_has) || CHR(10) || CHR(13);
				  else
				    exit;
				  end if;
				end if;			
      END LOOP;
      IF v_mess IS NOT NULL THEN
        v_titulo :=
            'Atención. Existen calificaciones de instrumentos y emisores vencidas o por vencer'; --por vencer el '
            --|| TO_CHAR(v_fec - 1);
        FOR d IN c_usr LOOP
          IF  d.email IS NOT NULL AND INSTR(d.email, '@') > 0 THEN
            IF v_mail_princ IS NULL THEN
              v_mail_princ := d.email;
            ELSE
              IF v_otr_mail IS NOT NULL THEN
                v_otr_mail := v_otr_mail || ';';
              END IF;
              v_otr_mail := NVL(v_otr_mail, '') || d.email;
            END IF;
          END IF;
        END LOOP;
        IF v_mail_princ IS NOT NULL THEN
          BEGIN
					 --v_mess := NVL(v_mess, '')|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					 --         '** Tildes omitidas por el generador de correos **';
            enviar_correo(
              'supen_mensajeria@supen.fi.cr', v_mail_princ,
              v_otr_mail || ';oreamunoae@supen.fi.cr;vargasqg@supen.fi.cr;rojasvi@supen.fi.cr',
              v_titulo, v_mess);
          EXCEPTION
            WHEN OTHERS THEN
              INSERT INTO eduardo
                   VALUES ('Error enviando correo '|| v_titulo || ' '
                           || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
          END;
        END IF;
      END IF;
      UPDATE tg_par_gen
         SET val_par = TO_CHAR(v_fec, 'dd-mm-yyyy')
       WHERE cod_par = 'FECAVI';
      COMMIT;
    END IF;
	exception 
	  when others then 
		INSERT INTO eduardo
          VALUES ('Error p_emis_venc ' || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
  END;

  PROCEDURE p_rev_sol_pen IS
    CURSOR c_pen IS
      SELECT 'Sol ' || TO_CHAR(con_sol) || ' de ' || abr_ent || '-' || cod_fon
             || ' del ' || TO_CHAR(fec_dat, 'dd-mm-yyyy') || ' que inicio a las '
             || TO_CHAR(inicio, 'dd-mm-yyyy HH24:mi:ss') || ' y tiene '
             || TO_CHAR(
                  (SYSDATE - inicio) * (24 * 60), '999.999')
             || ' min.' mensaje,
             (SYSDATE - inicio) * (24 * 60) tiempo,
             'TG_SOL_PRO' tabla, con_sol
        FROM tg_sol_pro
       WHERE (cod_rep IN ('VM', 'SC', 'VF', 'SF')
              OR (cod_rep IN ('AF05', 'AF04')
                  AND cod_pro NOT IN ('31', '29', '30', '32', '47', '48', '49')))
             AND (SYSDATE - inicio) * (24 * 60) > 45   -- Antes 15
      UNION
      SELECT 'Sol ' || TO_CHAR(con_sol) || ' de ' || abr_ent || '-' || cod_fon
             || ' del ' || TO_CHAR(fec_dat, 'dd-mm-yyyy') || ' que inicio a las '
             || TO_CHAR(inicio, 'dd-mm-yyyy HH24:mi:ss') || ' y tiene '
             || TO_CHAR(
                  (SYSDATE - inicio) * (24 * 60), '999.999')
             || ' min.',
             (SYSDATE - inicio) * (24 * 60) tiempo,
             'TG_SOL_PEN' tabla, con_sol
        FROM tg_sol_pen
       WHERE estado < 2 AND cod_rep IN ('VM', 'SC', 'VF', 'SF')
             AND (SYSDATE - inicio) * (24 * 60) > 45;  -- ANtes 15

    CURSOR c_pen_afi IS
      SELECT 'Sol. ' || ' de ' || abr_ent || ' ' || cod_rep || ' del '
             || TO_CHAR(fec_dat, 'dd-mm-yyyy') || ' que inicio a las '
             || TO_CHAR(fec_job, 'dd-mm-yyyy HH24:mi:ss') || ' y tiene '
             || TO_CHAR(
                  (SYSDATE - fec_job) * (24), '999999')
             || ' horas.' mensaje,
             (SYSDATE - fec_job) * (24) tiempo,
             'AF2_JOB_INC' tabla, estado, cod_usr
        FROM af2_job_inc@afil
       WHERE (SYSDATE - fec_job) * (24) > 12
             AND estado <> 2;

    /*select a.abr_ent||' '||a.fec_dat||' '||b.mensaje mensaje, a.cod_usr
      from af2_job_inc@afil a;*/
    v_mess VARCHAR2(2500);
    v_mail_princ VARCHAR2(300) := 'pughvk@supen.fi.cr';
    v_otr_mail VARCHAR2(3000)
  := 'oreamunoae@supen.fi.cr;vargasqg@supen.fi.cr;hidalgoco@supen.fi.cr;rojasvi@supen.fi.cr';
  BEGIN
    v_mess := NULL;
    FOR c IN c_pen LOOP
      v_mess := NVL(v_mess, '') || c.mensaje || ' ' || CHR(10) || CHR(13);
      -- Se modifica para que cuando tenga más de 20 minutos en tg_sol_pro
      -- de procesarse se reinicie
      IF  c.tiempo > 15 AND c.tabla = 'TG_SOL_PRO' THEN
        UPDATE tg_sol_pro
           SET estado = 1
         WHERE con_sol = c.con_sol;
        COMMIT;
      END IF;
    END LOOP;
    -- Aqui se envia el correo que no sse ha enviado por
    -- el funcionamiento del cursor
      -- Se modifca para que nop envie el mensaje despues de las
      -- 6:00 pm
    IF TO_NUMBER(TO_CHAR(SYSDATE, 'HH24')) BETWEEN 7 AND 17 THEN
      IF v_mess IS NOT NULL THEN
				  --v_mess := NVL(v_mess, '')|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					 --         '** Tildes omitidas por el generador de correos **';
        BEGIN
          enviar_correo(
            'supen_mensajeria@supen.fi.cr', v_mail_princ, v_otr_mail,
            'Solicitudes pendientes con más de 15 min. sin ser atendidas',
            v_mess);
        EXCEPTION
          WHEN OTHERS THEN
            INSERT INTO eduardo
                 VALUES ('Error enviando correo de solicitudes pendientes'
                         || ' ' || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
        END;
      END IF;
    END IF;
    v_mess := '';
    v_otr_mail := '';
  /*for c in c_pen_afi loop
     select nvl(v_otr_mail||';','')||email into v_otr_mail
      from tg_usr
      where cod_usr = c.cod_usr;
     v_mess := NVL(v_mess, '') || c.mensaje || CHR(10) || CHR(13);
  end loop;
  if v_mess is not null then
    enviar_correo(
    'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr', v_otr_mail,
    'Solicitudes de afiliados con más de un día de proceso aún pendientes o en proceso.', v_mess);
  end if;*/
	exception 
	  when others then 
		INSERT INTO eduardo
          VALUES ('Error p_rev_sol_pen ' || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
  END;

  PROCEDURE p_calc_renta IS
    CURSOR c_dat IS
      SELECT   MAX(a.fec_dat) fec_dat, a.cod_ent, a.cod_fon
          FROM tg_bit a, tg_fon_ent b --, tg_fon_reg c
         WHERE a.cod_rep = 'SC' AND --decode(substr(:global.depto,1,1),'O','SC','SF') AND 
                                   a.cod_pro = '03'
               AND --decode(substr(:global.depto,1,1),'O','03','73') AND --'03'
                  a.cod_ent NOT IN ('X10', 'A99', 'A98', 'A08')
               AND a.fec_dat > ADD_MONTHS(SYSDATE, -3) AND a.fin = 3
               AND --a.cod_fon not in ('09','10') and
                  b.cod_ent = a.cod_ent AND b.cod_fon = a.cod_fon
               AND NVL(b.activo, 'S') = 'S'
      GROUP BY a.cod_ent, a.cod_fon
      ORDER BY 1;

    v_fec_rent DATE;
    v_fec_pro DATE;
    v_ipc NUMBER := 0;
  BEGIN
    IF TO_CHAR(SYSDATE, 'HH24') > 8 THEN
      SELECT MAX(fec_dat)
        INTO v_fec_rent
        FROM dis_cal_id_inf_fin
       WHERE fec_dat > ADD_MONTHS(SYSDATE, -3) AND cod_ent LIKE 'A%';
      FOR c IN c_dat LOOP
        v_fec_pro := c.fec_dat;
        EXIT;
      END LOOP;
		  if v_fec_pro > add_months(v_fec_rent,1) then
		    v_fec_pro := add_months(v_fec_rent,1);
  		end if; 			
      --select add_months(last_day(max(v_fec_pro)),-1)
      --into v_fec_pro from dual;
/*    from tg_bit
      where cod_rep in ('SC') --('VM','VF')
     and cod_pro in ('03') --('67','83')
     and fin = 3
      and fec_dat > add_months(sysdate,-3); */

      IF  TO_CHAR(v_fec_pro, 'DD') = '30'
          AND LAST_DAY(ADD_MONTHS(v_fec_rent, 1)) = v_fec_pro + 1 THEN
          BEGIN
            enviar_correo(
              'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
              'vargasqg@supen.fi.cr;changkd@supen.fi.cr;alvaradomr@supen.fi.cr;cespedesld@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
              'Inicio de calculo de rentabilidad nominal (anticipada) del '
              || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
              'Inicio de calculo de rentabilidad anticipado del '
              || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
              || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
							--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					    --      '** Tildes omitidas por el generador de correos **');
          EXCEPTION
            WHEN OTHERS THEN
              INSERT INTO eduardo
                   VALUES ('Error enviando correo inicio cálculo de rentabilidad del '
                           || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                           || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
          END;
          pr_k_rep_excel.p_rentab(1, v_fec_pro, 1, 'C');
          pr_k_rep_excel.p_rentab(2, v_fec_pro, 2, 'C');
          pr_k_rep_excel.p_rentab(1, v_fec_pro, 1, 'B');
          pr_k_rep_excel.p_rentab(2, v_fec_pro, 2, 'B');
          enviar_correo(
            'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
            'vargasqg@supen.fi.cr;changkd@supen.fi.cr;alvaradomr@supen.fi.cr;cespedesld@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
            'Fin de calculo de rentabilidad nominal (anticipada) del '
            || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
            'Fin de calculo de rentabilidad anticipado del '
            || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
            || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
						--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					  --        '** Tildes omitidas por el generador de correos **');
        --END IF;
      ELSE
        IF LAST_DAY(ADD_MONTHS(v_fec_rent, 1)) <= v_fec_pro THEN
		      v_fec_pro :=  last_day(ADD_MONTHS(v_fec_rent, 1));
          BEGIN
              enviar_correo(
                'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
                'vargasqg@supen.fi.cr;changkd@supen.fi.cr;alvaradomr@supen.fi.cr;cespedesld@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
                'Inicio de calculo de rentabilidad nominal del '
                || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
                'Inicio de calculo de rentabilidad del '
                || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
                || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
								--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					      --    '** Tildes omitidas por el generador de correos **');
          EXCEPTION
              WHEN OTHERS THEN
                INSERT INTO eduardo
                     VALUES ('Error enviando correo cálculo de rentabilidad  del '
                             || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                             || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
          END;

          pr_k_rep_excel.p_rentab(1, v_fec_pro, 1, 'C');
          pr_k_rep_excel.p_rentab(2, v_fec_pro, 2, 'C');
          pr_k_rep_excel.p_rentab(1, v_fec_pro, 1, 'B');
          pr_k_rep_excel.p_rentab(2, v_fec_pro, 2, 'B');

          BEGIN
              enviar_correo(
                'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
                'vargasqg@supen.fi.cr;changkd@supen.fi.cr;alvaradomr@supen.fi.cr;cespedesld@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
                'Fin de calculo de rentabilidad nominal del '
                || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
                'Fin de calculo de rentabilidad del '
                || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
                || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
								--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					      --    '** Tildes omitidas por el generador de correos **');
          EXCEPTION
              WHEN OTHERS THEN
                INSERT INTO eduardo
                     VALUES ('Error enviando correo cálculo de rentabilidad  del '
                             || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                             || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
          END;
        END IF;
      END IF;
			
			IF TO_CHAR(SYSDATE, 'DD') > 7 THEN -- Por que el IPC estará hasta el 5to día habil
				
				SELECT MAX(fec_dat)
	      INTO v_fec_rent
	      FROM dis_cal_id_inf_fin
	      WHERE fec_dat > ADD_MONTHS(SYSDATE, -3) AND cod_ent LIKE 'A%'
				and tip_rep in ('R1','R2');
				if LAST_DAY(ADD_MONTHS(v_fec_rent, 1)) > v_fec_pro then
				  null;
				else 
				  SELECT MAX(fec_dat) into v_fec_pro
	        FROM dis_cal_id_inf_fin
	        WHERE fec_dat > ADD_MONTHS(SYSDATE, -3) AND cod_ent LIKE 'A%'
				  and tip_rep not in ('R1','R2');
	          pr_k_rep_excel.p_rentab_real(1, v_fec_pro, 1);
	          pr_k_rep_excel.p_rentab_real(2, v_fec_pro, 2);
				end if;
			END IF;
    END IF;
  END;

  PROCEDURE p_calc_esta_web IS
    CURSOR c_dat IS
      SELECT   MAX(a.fec_dat) fec_dat, a.cod_ent, a.cod_fon
          FROM tg_bit a, tg_fon_ent b, tg_fon c
         WHERE a.cod_rep = 'VM' AND a.cod_pro = '67'
               AND a.cod_ent NOT IN ('X10', 'A99', 'A98', 'A08')
               AND a.fec_dat > ADD_MONTHS(SYSDATE, -3) AND a.fin = 3
               AND b.cod_ent = a.cod_ent AND b.cod_fon = a.cod_fon
               AND NVL(b.activo, 'S') = 'S'
			   and c.cod_fon = b.cod_fon
			   and c.fon_par <> 'E'
      GROUP BY a.cod_ent, a.cod_fon
      ORDER BY 1;

    CURSOR c_dat_se IS
		  SELECT   MAX(a.fec_dat) fec_dat, a.cod_ent, a.cod_fon
          FROM tg_bit a, tg_fon_ent b
         WHERE a.cod_rep = 'SE' AND a.cod_pro = '70'
               AND a.cod_ent NOT IN ('X10', 'A99', 'A98', 'A08')
               AND a.fec_dat > ADD_MONTHS(SYSDATE, -3) AND a.fin = 3
               AND b.cod_ent = a.cod_ent AND b.cod_fon = a.cod_fon
               AND NVL(b.activo, 'S') = 'S'
      GROUP BY a.cod_ent, a.cod_fon
      ORDER BY 1;
			
    v_fec_rent DATE;
    v_fec_pro DATE;
    p_sec NUMBER;
    p_tip_rep NUMBER;
    p_dolar VARCHAR2(200);
    p_opc VARCHAR2(200);
    v_tiene_datos varchar2(1) := 'N';
    CURSOR c_dat1(p_sec IN INTEGER) IS
      SELECT *
        FROM mv_rep_tmp
       WHERE num_sec = p_sec;
  BEGIN
    --if to_char(sysdate,'HH24') > 0 then
		
		begin
		SELECT 1
    INTO p_sec
    FROM tg_usr
    WHERE cod_usr = USER
		and NVL(tip_dep, 'X') = 'O';
		exception
		  when no_data_found then p_sec := 0;
		end;

    if nvl(p_sec,0) > 0 then
    SELECT MAX(fec_dat)
      INTO v_fec_rent
      FROM mv_est_inv
     WHERE fec_dat > ADD_MONTHS(SYSDATE, -3) AND cod_ent LIKE 'A%';
    FOR c IN c_dat LOOP
      v_fec_pro := c.fec_dat;
      EXIT;
    END LOOP;
		
		if v_fec_pro > add_months(v_fec_rent,1) then
		  v_fec_pro := add_months(v_fec_rent,1);
		end if;
      --select add_months(last_day(max(v_fec_pro)),-1)
      --into v_fec_pro from dual;
/*    from tg_bit
      where cod_rep in ('SC') --('VM','VF')
     and cod_pro in ('03') --('67','83')
     and fin = 3
      and fec_dat > add_months(sysdate,-3); */

    IF LAST_DAY(ADD_MONTHS(v_fec_rent, 1)) = v_fec_pro THEN
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;changkd@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
          'Inicio de calculo de estadisticas para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Inicio de calculo de estadisticas para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
					--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					--          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de estadisticas para web del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;

      p_sec := TO_CHAR(v_fec_pro, 'YYYYMM');
      p_dolar := 'N';
      p_opc := 'C';
      FOR i IN 1 .. 4 LOOP
        p_tip_rep := i;
        DELETE      mv_rep_tmp
              WHERE num_sec = p_sec;
        inadm.pr_k_rep_excel.p_mv_rep_tmp_excel(
          p_sec, v_fec_pro, p_tip_rep, p_dolar, p_opc);
        FOR c IN c_dat1(p_sec) LOOP
				  v_tiene_datos := 'S';
          INSERT INTO mv_est_inv
                      (num_sec, tip_rep, cod_reg, cod_ent, cod_fon, fec_dat,
                       cod_sec, cod_ins, cod_aux, cod_mon, tip_cam, monto,
                       rango, cod_mon_ins, fec_gen)
               VALUES (c.num_sec, p_tip_rep, c.cod_reg, c.cod_ent, c.cod_fon,
                       c.fec_dat, c.cod_sec, c.cod_ins, c.cod_emi, c.cod_mon,
                       c.tip_cam, c.monto, c.rango, c.cod_cta, SYSDATE);
        END LOOP;
        COMMIT;
        DELETE      mv_rep_tmp
        WHERE num_sec = p_sec;
      END LOOP;

      if v_tiene_datos = 'S' then
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;changkd@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
          'Fin de calculo de estadisticas para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Fin de calculo de estadisticas para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
					--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					--          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de estadisticas para web del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;
			else
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;changkd@supen.fi.cr',
          'Sin datos para el calculo de estadisticas para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.Revise depto (TG_USR).',
          'Sin datos para el calculo de estadisticas para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
					--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					--          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de estadisticas para web del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;			
			end if;
    END IF;
		
-- Aqui se procesan los estados finacieros		
    SELECT MAX(fec_dat)
      INTO v_fec_rent
      FROM se_rep_web
     WHERE fec_dat > ADD_MONTHS(SYSDATE, -3) AND cod_ent LIKE 'A%';
    FOR c IN c_dat_se LOOP
      v_fec_pro := c.fec_dat;
      EXIT;
    END LOOP;
		
		if v_fec_pro > add_months(v_fec_rent,1) then
		  v_fec_pro := add_months(v_fec_rent,1);
		end if; 
		
-- Se le agrego el <= por que si es menor significa que no se ha ejecutado el claculo.
    IF LAST_DAY(ADD_MONTHS(v_fec_rent, 1)) <= v_fec_pro THEN
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;changkd@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
          'Inicio de calculo de estados financieros para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Inicio de calculo de estados financieros para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
					--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					--          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de estados financieros para web del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;

      FOR i IN 1 .. 2 LOOP
			  if i = 1 then
          p_tip_rep := i;
				else
				  p_tip_rep := 9;
			  end if;			
--
        declare
          cursor c_dat is 
            select * from tg_bit
            where fec_dat = v_fec_pro
            and cod_fon = 'IF'
            and cod_pro = '70'
            and fin = 3;
        begin
          for c1 in c_dat loop
            insert into se_rep_web
              select user, linea, substr(des_lin,1,100), saldo, nivel, 
						       c1.cod_ent,c1.fec_dat,sysdate,p_tip_rep 
			        from (select b.linea linea, 
                     --RPAD(' ', b.nivel*3)||
										 e.nom_cta des_lin, 
                     b.nivel nivel, 
                     sum(nvl(d.sdo_cta,0)*b.signo) saldo
                     from tg_est_fin b, id_inf_fin d, tg_cag_cta_ent e
                     where d.fec_dat (+)= c1.fec_dat
                     and d.cod_fon (+)= c1.cod_fon
                     and d.cod_ent (+)= c1.cod_ent
                     and d.cod_cta  (+)= b.cod_cta
                     and b.busca_cta = 'S'
                     and nvl(b.calc_desp,'N') <> 'S'
                     and b.tip_est_fin = p_tip_rep
                     and e.cod_cta = b.cod_cta 
                     group by b.linea, e.nom_cta, b.nivel
              union
              select b.linea linea, --RPAD(' ', b.nivel*3)||
							       b.des_lin des_lin,
							       b.nivel,sum(nvl(d.sdo_cta,0)*c.signo) saldo
                     from tg_est_fin b, tg_est_fin_det c, id_inf_fin d
                     where d.fec_dat (+)= c1.fec_dat
                     and d.cod_fon (+)= c1.cod_fon
                     and d.cod_ent (+)= c1.cod_ent
                     and d.cod_cta (+)= c.cod_cta
                     and b.tip_est_fin = p_tip_rep
                     and nvl(b.busca_cta,'N') <> 'S'
                     and nvl(b.calc_desp,'N') <> 'S'
                     and c.tip_est_fin = b.tip_est_fin
                     and c.linea = b.linea
                     group by b.linea, b.des_lin, b.nivel)
              order by 2;
-- Inserta lineas que se suman con las acumuladas							
			      insert into se_rep_web
				      select user, a.LINEA, --RPAD(' ', a.nivel*3)||
							   a.DES_LIN des_lin, 
							   sum(nvl(b1.monto*b.signo,0)), a.nivel,
				         c1.cod_ent,c1.fec_dat,sysdate,p_tip_rep
              from tg_est_fin a, tg_est_fin_det b, se_rep_web b1
              where a.tip_est_fin = p_tip_rep
              and  a.calc_desp = 'S'
              and b.tip_est_fin = a.tip_est_fin
              and b.linea = a.linea
              and b1.cod_usu = user
              and b1.tip_rep = a.tip_est_fin
              and b1.num_linea = b.linea_calc
              and b1.cod_ent = c1.cod_ent
              and b1.fec_dat = c1.fec_dat
              group by a.linea, a.des_lin, a.nivel;
-- Inserta lineas de encabezados, sin monto							
				    insert into se_rep_web
				      select  user, LINEA, --RPAD(' ', nivel*3)||
							  DES_LIN, null, nivel, 
							  c1.cod_ent,c1.fec_dat,sysdate,p_tip_rep
              from tg_est_fin a
              where nvl(a.busca_cta,'N') <> 'S'
              and tip_est_fin = p_tip_rep 
              and not exists (select 1 from tg_est_fin_det b
                        where b.linea = a.linea
												and b.tip_est_fin = a.tip_est_fin);
	        end loop;
        end;
--			
        COMMIT;
      END LOOP;

      
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;changkd@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
          'Fin de calculo de estados financieros para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Fin de calculo de estados financieros para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
					--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					--          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de estados financieros para web del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;

    END IF;
		else
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;changkd@supen.fi.cr',
          'No pudo ejecutar el calculo de estados financieros para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Parametro de usuario incorrecto del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
		end if;				
  END;

  PROCEDURE p_calc_esta_web_rc IS
    CURSOR c_dat IS
      SELECT   MAX(a.fec_dat) fec_dat, a.cod_ent, a.cod_fon
          FROM tg_bit a, tg_fon_ent b --, tg_fon_reg c
         WHERE a.cod_rep = 'VF' AND --decode(substr(:global.depto,1,1),'O','SC','SF') AND 
                                   a.cod_pro = '83'
               AND --decode(substr(:global.depto,1,1),'O','03','73') AND --'03'
                  a.cod_ent NOT IN ('X10', 'A99', 'A98', 'A08') and a.cod_fon in ('93','94')
               AND a.fec_dat > ADD_MONTHS(SYSDATE, -3) AND a.fin = 3
               AND --a.cod_fon not in ('09','10') and
                  b.cod_ent = a.cod_ent AND b.cod_fon = a.cod_fon
               AND NVL(b.activo, 'S') = 'S'
      GROUP BY a.cod_ent, a.cod_fon
      ORDER BY 1;

/*    CURSOR c_dat_se IS
		  SELECT   MAX(a.fec_dat) fec_dat, a.cod_ent, a.cod_fon
          FROM tg_bit a, tg_fon_ent b
         WHERE a.cod_rep = 'SE' AND a.cod_pro = '70'
               AND a.cod_ent NOT IN ('X10', 'A99', 'A98', 'A08')
               AND a.fec_dat > ADD_MONTHS(SYSDATE, -3) AND a.fin = 3
               AND b.cod_ent = a.cod_ent AND b.cod_fon = a.cod_fon
               AND NVL(b.activo, 'S') = 'S'
      GROUP BY a.cod_ent, a.cod_fon
      ORDER BY 1;
*/			
    v_fec_rent DATE;
    v_fec_pro DATE;
    p_sec NUMBER;
    p_tip_rep NUMBER;
    p_dolar VARCHAR2(200);
    p_opc VARCHAR2(200);

    CURSOR c_dat1(p_sec IN INTEGER) IS
      SELECT *
        FROM mv_rep_tmp
       WHERE num_sec = p_sec;
  BEGIN
    --if to_char(sysdate,'HH24') > 0 then

    SELECT MAX(fec_dat)
      INTO v_fec_rent
      FROM mv_est_inv
     WHERE fec_dat > ADD_MONTHS(SYSDATE, -12) AND cod_ent LIKE 'E%';
    FOR c IN c_dat LOOP
      v_fec_pro := c.fec_dat;
      EXIT;
    END LOOP;
		
		if v_fec_pro > add_months(v_fec_rent,1) then
		  v_fec_pro := add_months(v_fec_rent,1);
		end if; 
      --select add_months(last_day(max(v_fec_pro)),-1)
      --into v_fec_pro from dual;
/*    from tg_bit
      where cod_rep in ('SC') --('VM','VF')
     and cod_pro in ('03') --('67','83')
     and fin = 3
      and fec_dat > add_months(sysdate,-3); */

    IF LAST_DAY(ADD_MONTHS(v_fec_rent, 1)) <= v_fec_pro THEN
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;changkd@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
          'Inicio de calculo de estadisticas de RC para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Inicio de calculo de estadisticas de RC para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
					--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					--          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de estadisticas de RC para web del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;

      p_sec := TO_CHAR(v_fec_pro, 'YYYYMM');
      p_dolar := 'N';
      p_opc := 'C';
      FOR i IN 1 .. 4 LOOP
        p_tip_rep := i;
        DELETE      mv_rep_tmp
              WHERE num_sec = p_sec;
        inadm.pr_k_rep_excel.p_mv_rep_tmp_exc_RC(
          p_sec, v_fec_pro, p_tip_rep, p_dolar, p_opc);
        FOR c IN c_dat1(p_sec) LOOP
          INSERT INTO mv_est_inv
                      (num_sec, tip_rep, cod_reg, cod_ent, cod_fon, fec_dat,
                       cod_sec, cod_ins, cod_aux, cod_mon, tip_cam, monto,
                       rango, cod_mon_ins, fec_gen)
               VALUES (c.num_sec, p_tip_rep, c.cod_reg, c.cod_ent, c.cod_fon,
                       c.fec_dat, c.cod_sec, c.cod_ins, c.cod_emi, c.cod_mon,
                       c.tip_cam, c.monto, c.rango, c.cod_cta, SYSDATE);
        END LOOP;
        COMMIT;
        DELETE      mv_rep_tmp
              WHERE num_sec = p_sec;
      END LOOP;

      
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;changkd@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
          'Fin de calculo de estadisticas de RC para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Fin de calculo de estadisticas de RC para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
					--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					--          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de estadisticas de RC para web del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;
    END IF;
		
-- Aqui se procesan los estados finacieros		
/*    SELECT MAX(fec_dat)
      INTO v_fec_rent
      FROM se_rep_web
     WHERE fec_dat > ADD_MONTHS(SYSDATE, -2) AND cod_ent LIKE 'A%';
    FOR c IN c_dat_se LOOP
      v_fec_pro := c.fec_dat;
      EXIT;
    END LOOP;
-- Se le agrego el <= por que si es menor significa que no se ha ejecutado el claculo.
    IF LAST_DAY(ADD_MONTHS(v_fec_rent, 1)) <= v_fec_pro THEN
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;quesadacw@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
          'Inicio de calculo de estados financieros para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Inicio de calculo de estados financieros para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.'|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de estados financieros para web del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;

      FOR i IN 1 .. 2 LOOP
			  if i = 1 then
          p_tip_rep := i;
				else
				  p_tip_rep := 9;
			  end if;			
--
        declare
          cursor c_dat is 
            select * from tg_bit
            where fec_dat = v_fec_pro
            and cod_fon = 'IF'
            and cod_pro = '70'
            and fin = 3;
        begin
          for c1 in c_dat loop
            insert into se_rep_web
              select user, linea, substr(des_lin,1,100), saldo, nivel, 
						       c1.cod_ent,c1.fec_dat,sysdate,p_tip_rep 
			        from (select b.linea linea, 
                     --RPAD(' ', b.nivel*3)||
										 e.nom_cta des_lin, 
                     b.nivel nivel, 
                     sum(nvl(d.sdo_cta,0)) saldo
                     from tg_est_fin b, id_inf_fin d, tg_cag_cta_ent e
                     where d.fec_dat (+)= c1.fec_dat
                     and d.cod_fon (+)= c1.cod_fon
                     and d.cod_ent (+)= c1.cod_ent
                     and d.cod_cta  (+)= b.cod_cta
                     and b.busca_cta = 'S'
                     and nvl(b.calc_desp,'N') <> 'S'
                     and b.tip_est_fin = p_tip_rep
                     and e.cod_cta = b.cod_cta 
                     group by b.linea, e.nom_cta, b.nivel
              union
              select b.linea linea, --RPAD(' ', b.nivel*3)||
							       b.des_lin des_lin,
							       b.nivel,sum(nvl(d.sdo_cta,0)*c.signo) saldo
                     from tg_est_fin b, tg_est_fin_det c, id_inf_fin d
                     where d.fec_dat (+)= c1.fec_dat
                     and d.cod_fon (+)= c1.cod_fon
                     and d.cod_ent (+)= c1.cod_ent
                     and d.cod_cta (+)= c.cod_cta
                     and b.tip_est_fin = p_tip_rep
                     and nvl(b.busca_cta,'N') <> 'S'
                     and nvl(b.calc_desp,'N') <> 'S'
                     and c.tip_est_fin = b.tip_est_fin
                     and c.linea = b.linea
                     group by b.linea, b.des_lin, b.nivel)
              order by 2;
-- Inserta lineas que se suman con las acumuladas							
			      insert into se_rep_web
				      select user, a.LINEA, --RPAD(' ', a.nivel*3)||
							   a.DES_LIN des_lin, 
							   sum(nvl(b1.monto*b.signo,0)), a.nivel,
				         c1.cod_ent,c1.fec_dat,sysdate,p_tip_rep
              from tg_est_fin a, tg_est_fin_det b, se_rep_web b1
              where a.tip_est_fin = p_tip_rep
              and  a.calc_desp = 'S'
              and b.tip_est_fin = a.tip_est_fin
              and b.linea = a.linea
              and b1.cod_usu = user
              and b1.tip_rep = a.tip_est_fin
              and b1.num_linea = b.linea_calc
              and b1.cod_ent = c1.cod_ent
              and b1.fec_dat = c1.fec_dat
              group by a.linea, a.des_lin, a.nivel;
-- Inserta lineas de encabezados, sin monto							
				    insert into se_rep_web
				      select  user, LINEA, --RPAD(' ', nivel*3)||
							  DES_LIN, null, nivel, 
							  c1.cod_ent,c1.fec_dat,sysdate,p_tip_rep
              from tg_est_fin a
              where nvl(a.busca_cta,'N') <> 'S'
              and tip_est_fin = p_tip_rep 
              and not exists (select 1 from tg_est_fin_det b
                        where b.linea = a.linea
												and b.tip_est_fin = a.tip_est_fin);
	        end loop;
        end;
--			
        COMMIT;
      END LOOP;

      
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;ortizgv@supen.fi.cr;quesadacw@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
          'Fin de calculo de estados financieros para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Fin de calculo de estados financieros para web del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.'|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de estados financieros para web del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;

    END IF;		
*/		
  END;


  PROCEDURE p_calc_renta_rc IS
    CURSOR c_dat IS
      SELECT   MAX(a.fec_dat) fec_dat, a.cod_ent, a.cod_fon
          FROM tg_bit a, tg_fon_ent b --, tg_fon_reg c
         WHERE a.cod_rep = 'SF' AND --decode(substr(:global.depto,1,1),'O','SC','SF') AND 
                                   a.cod_pro = '73' AND --decode(substr(:global.depto,1,1),'O','03','73') AND --'03'
                                                       a.cod_ent <> 'X10'
               AND a.fec_dat > ADD_MONTHS(SYSDATE, -3) AND a.fin = 3
               AND --a.cod_fon not in ('09','10') and
                  b.cod_ent = a.cod_ent AND b.cod_fon = a.cod_fon
               AND NVL(b.activo, 'S') = 'S'
      GROUP BY a.cod_ent, a.cod_fon
      ORDER BY 1;

    v_fec_rent DATE;
    v_fec_pro DATE;
  BEGIN
	  
		-- Se pone para darle tiempo a que se incluya el ipc
		if to_number(to_char(sysdate,'DD')) > 7 then
		
    SELECT MAX(fec_dat)
      INTO v_fec_rent
      FROM dis_cal_id_inf_fin
     WHERE fec_dat > ADD_MONTHS(SYSDATE, -3) AND cod_ent LIKE 'E%';
    FOR c IN c_dat LOOP
      v_fec_pro := c.fec_dat;
      EXIT;
    END LOOP;
		
		if v_fec_pro > add_months(v_fec_rent,1) then
		  v_fec_pro := add_months(v_fec_rent,1);
		end if; 		
      --select add_months(last_day(max(v_fec_pro)),-1)
      --into v_fec_pro from dual;
/*    from tg_bit
      where cod_rep in ('SC') --('VM','VF')
     and cod_pro in ('03') --('67','83')
     and fin = 3
      and fec_dat > add_months(sysdate,-3); */

    IF LAST_DAY(ADD_MONTHS(v_fec_rent, 1)) = v_fec_pro THEN
      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;changkd@supen.fi.cr;alvaradomr@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
          'Inicio de calculo de rentabilidad de RC del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Inicio de calculo de rentabilidad de RC del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
					--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					--          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de rentabilidad  RC del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;

      pr_k_rep_excel.p_renta_rc(1, v_fec_pro, 1, 'C', NULL);
      pr_k_rep_excel.p_renta_rc(2, v_fec_pro, 2, 'C', NULL);
      pr_k_rep_excel.p_renta_rc(1, v_fec_pro, 1, 'B', NULL);
      pr_k_rep_excel.p_renta_rc(2, v_fec_pro, 2, 'B', NULL);

      BEGIN
        enviar_correo(
          'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
          'vargasqg@supen.fi.cr;changkd@supen.fi.cr;alvaradomr@supen.fi.cr;corralesvr@supen.fi.cr;mendezzp@supen.fi.cr',
          'Fin de calculo de rentabilidad de RC del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || '.',
          'Fin de calculo de rentabilidad de RC del '
          || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' a las '
          || TO_CHAR(SYSDATE, 'HH24:MI:SS') || '.');
					--|| CHR(10) || CHR(13)|| CHR(10) || CHR(13)||
					--          '** Tildes omitidas por el generador de correos **');
      EXCEPTION
        WHEN OTHERS THEN
          INSERT INTO eduardo
               VALUES ('Error enviando correo cálculo de rentabilidad RC del '
                       || TO_CHAR(v_fec_pro, 'dd-mm-yyyy') || ' '
                       || TO_CHAR(SYSDATE, 'DD-MM-YYYY HH24:MI:SS'));
      END;
    END IF;
		end if;
  END;
  
procedure p_mens_cobro is
  cursor c_ent is
    select * from cs_ent
    where estado = 'A';
 v_dia_avi cs_mes_cob.dia_avi%type;
 v_mes_avi cs_mes_cob.mes_avi%type;
 v_dia_cob cs_mes_cob.dia_cob%type;
 v_mes_cob cs_mes_cob.mes_cob%type;
 v_mes_avisado cs_mes_cob.mes_avi%type := 0;
 v_fec_cob date;
 v_mensaje varchar2(4000);
 v_asunto varchar2(200); 
 v_mes varchar2(20);  
 v_dias integer := 0;
 v_correo_adm varchar2(30) := 'valverdeam@supen.fi.cr';
Begin
--insert into eduardo values ('final paso 0'); commit;
  if to_number(to_char(sysdate+v_dias,'MM')) = 1 then
	-- Actualizar los parametros de cobro
		 update tg_par_gen
		 set val_par = 0
	   where cod_par = 'MESAVI'
		 and to_number(val_par) >= 10;
		 
		 update tg_par_gen
		 set val_par = 0
	   where cod_par = 'AVICYS'
		 and to_number(val_par) >= 10;	 	
		 commit;
	end if;
  begin
    select dia_avi, mes_avi, dia_cob, mes_cob
    into v_dia_avi, v_mes_avi,v_dia_cob, v_mes_cob
    from cs_mes_cob
    where mes = to_number(to_char(sysdate+v_dias,'MM'));
	  select decode(v_mes_cob,1,'Enero',
	                        2,'Febrero',
	                        3,'Marzo',
	                        4,'Abril',
	                        5,'Mayo',
	                        6,'Junio',
	                        7,'Julio',
	                        8,'Agosto',
	                        9,'Septiembre',
	                        10,'Octubre',
	                        11,'Noviembre','Diciembre') into v_mes from dual;																																																															
   exception
     when no_data_found then 
	   v_dia_avi := 0; v_mes_avi:= 0;
  end; 
  --dbms_output.put_line('paso 1 mes_avisado '||to_char(v_mes_avisado)||' mes '||to_char(v_mes_cob)) ; 
  if v_mes_avi > 0 then
    if to_number(to_char(sysdate+v_dias,'MM')) = v_mes_avi then
	  -- Busca el último mes avisado
	    select to_number(val_par)
  	  into v_mes_avisado 
	    from tg_par_gen
	    where cod_par = 'MESAVI';
	    -- Si el mes avisado es menor al actual
      -- debe verificar si corresponde al día del aviso
	    --dbms_output.put_line('paso 1 mes_avisado '||to_char(v_mes_avisado)||' mes '||to_char(v_mes_cob)) ; 
	    if v_mes_avisado < v_mes_avi and v_mes_avisado > 0 then
	      if to_number(to_char(sysdate+v_dias,'DD')) >= v_dia_avi then
		  -- debe enviar el aviso.
		      v_asunto := 'Asunto: Recordatorio cobro por supervisión '||v_mes||' '||to_char(sysdate,'YYYY');
          v_mensaje := 'Estimado Usuario(a):'|| CHR(10) || CHR(13)|| CHR(10) || CHR(13);
          v_mensaje := v_mensaje ||'Me permito recordarles que el cobro por servicios de supervisión,';
          v_mensaje := v_mensaje ||' correspondiente al mes de '||v_mes||' de '||to_char(sysdate,'YYYY');
		      v_mensaje := v_mensaje ||', se efectuará el '||to_char(v_dia_cob)||' de '||v_mes||' del '||to_char(sysdate,'YYYY')||'.'||chr(46)||CHR(10) || CHR(13)|| CHR(10) || CHR(13); 
          v_mensaje := v_mensaje ||'Los recursos deben estar depositados en la cuenta cliente autorizada';
		      v_fec_cob := to_date(to_char(v_dia_cob)||'-'||to_char(v_mes_cob)||'-'||to_char(sysdate,'YYYY'),'DD-MM-YYYY')-1;
		      loop
		        exit when es_habil(v_fec_cob) = 'S';
			      v_fec_cob := v_fec_cob - 1;
		      end loop;
			  -- Por mantenimiento del 14-08-2013 soicitado por Maricel
          --v_mensaje := v_mensaje ||' a más tardar el '||to_char(v_fec_cob,'DD')||' de '||v_mes||' de '||to_char(sysdate,'YYYY')||', a las 18 horas.'||CHR(10) || CHR(13)|| CHR(10) || CHR(13);
					v_mensaje := v_mensaje ||' a más tardar a las 3:00 p.m. de ese día.'||chr(46)||CHR(10) || CHR(13)|| CHR(10) || CHR(13);		
          v_mensaje := v_mensaje ||'De antemano agradezco su colaboración en el asunto referido y cualquier consulta sobre el particular puede efectuarla a la dirección electronica valverdeam@supen.fi.cr.'||chr(46)||CHR(10) || CHR(13)|| CHR(10) || CHR(13);
--          v_mensaje := v_mensaje || CHR(10) || CHR(13)|| CHR(10) || CHR(13)||'** Tildes omitidas por el generador de correos **';
    		  for e in c_ent loop
		    	  if e.cor_ele is not null and length(e.cor_ele) > 0 then
		     --enviar_correo('supen_mensajeria@supen.fi.cr', v_correo_adm,
			 --'oreamunoae@supen.fi.cr;vargasqg@supen.fi.cr;',v_asunto||' ('||e.cod_ent||')', v_mensaje);			 
  			      enviar_correo('supen_mensajeria@supen.fi.cr', v_correo_adm, replace(e.cor_ele,',',';'), 
                            v_asunto||' ('||e.cod_ent||')', v_mensaje);
			      end if;
		      end loop;
		      update tg_par_gen
		      set val_par = v_mes_avi
	        where cod_par = 'MESAVI';	
		      commit;
    		end if;
	    else
	      dbms_output.put_line('No enviar');
	    end if;
	  end if;
----------------------------
  -- 
  -- debe verificar si el día antes del cobro para enviar el mensaje 
  -- al funcionario de comunicación y servicios.
  if to_number(to_char(sysdate+v_dias,'MM')) = v_mes_cob then  
	  v_fec_cob := to_date(to_char(v_dia_cob)||'-'||to_char(v_mes_cob)||'-'||to_char(sysdate,'YYYY'),'DD-MM-YYYY');
	  /*loop
	    v_fec_cob := v_fec_cob; -- - 1; Se modifica por HD de Maricel del 29-09-15
		  exit when es_habil(v_fec_cob) = 'S';
	  end loop;*/
	  --dbms_output.put_line('aqui '||to_char(v_fec_cob)||' '||to_char(sysdate+v_dias));
	  if to_number(to_char(sysdate+v_dias,'DD')) = to_number(to_char(v_fec_cob,'DD')) then
	  -- Busca el último mes avisado a comunicación y servicios
	    select to_number(val_par)
      into v_mes_avisado 
	    from tg_par_gen
	    where cod_par = 'AVICYS';	  
      if v_mes_avisado < v_mes_cob and v_mes_avisado > 0 then
		  -- debe enviarle el mensaje a la funcionaria
		    v_asunto := 'Asunto: Recordatorio cobro por supervisión '||v_mes||' '||to_char(sysdate,'YYYY');
		    enviar_correo('supen_mensajeria@supen.fi.cr', v_correo_adm, 
          'oreamunoae@supen.fi.cr',v_asunto, 'Cobro por supervisión se aplica hoy');
		    update tg_par_gen
		    set val_par = v_mes_cob
	      where cod_par = 'AVICYS';	
		    commit;
		  end if;
	  end if;
	end if;	 
  end if;
end;
  
BEGIN

  update dif_afi
  set usr_inc_opc = substr(usr_inc_opc,1,5)
  where length(usr_inc_opc) > 5  
  and fec_txn between trunc(sysdate)-5 and trunc(sysdate);
	if sql%rowcount > 0 then
    commit;
		enviar_correo(
              'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
              'vargasqg@supen.fi.cr;rojasvi@supen.fi.cr',
              'Actualizó Incentivos fiscales', 'Actualizó Incentivos fiscales');
  end if;							

  -- Esto se hace por que aún no se cargan SC 
  -- de estos fondos.

  p_emis_venc;
--dbms_output.PUT_LINE('paso 1');  
  UPDATE mv_pro_pen
     SET estado = 2
  WHERE estado = 4;
  IF SQL%FOUND THEN
    COMMIT;
  END IF;

  UPDATE mv_pro_pen
     SET estado = 2
   WHERE ( --cod_fon IN ('50', '51', '52') OR 
          (cod_fon LIKE 'I%') OR (cod_ent = 'E01')) AND estado = 1;
  IF SQL%FOUND THEN
    COMMIT;
  END IF;
--dbms_output.PUT_LINE('paso 2');	
  rev_datos;
--dbms_output.PUT_LINE('paso 3');	
  p_rev_sol_pen;
--dbms_output.PUT_LINE('paso 4');
--insert into eduardo values ('final paso 1'); commit;	
  SELECT COUNT(*)
    INTO v_tot_pro
    FROM mv_pro_pen
   WHERE estado = 3;
  v_en_proceso := 'N';
  IF NVL(v_tot_pro, 0) <= v_tot_eje THEN
    OPEN c_sol_mv;
    LOOP
      FETCH c_sol_mv INTO v_cod_ent, v_cod_fon, v_fec_dat, v_cod_ref,
                          v_estado, v_num_sol;
      EXIT WHEN c_sol_mv%NOTFOUND;
      IF v_cod_ent IS NOT NULL THEN
        SELECT pro_pre
          INTO gv_pro_pre
          FROM tg_ent
         WHERE cod_ent = v_cod_ent;

        BEGIN
          SELECT 'S'
            INTO v_en_proceso
            FROM mv_pro_pen
           WHERE cod_ent = v_cod_ent AND cod_fon = v_cod_fon
                 AND fec_dat <= v_fec_dat AND estado IN (3, 4); -- En proceso o con errores
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_en_proceso := 'N';
          WHEN TOO_MANY_ROWS THEN
            v_en_proceso := 'S';
        END;

        IF v_en_proceso = 'N' THEN
          EXIT;
        END IF;
      END IF;
    END LOOP;
    CLOSE c_sol_mv;
  END IF;
--insert into eduardo values ('final paso 2'); commit;	
  IF v_cod_ent IS NOT NULL THEN
		if substr(v_cod_ent,1,1) <> 'E' then
      UPDATE mv_pro_pen
      SET estado = 3
      WHERE cod_ent = v_cod_ent AND cod_fon = v_cod_fon
      AND fec_dat = v_fec_dat AND num_sol = v_num_sol;
		else
      UPDATE mv_pro_pen
      SET estado = 3
      WHERE cod_ent = v_cod_ent --AND cod_fon = v_cod_fon
      AND fec_dat = v_fec_dat; -- AND num_sol = v_num_sol;
		end if;  
/*    UPDATE mv_pro_pen
       SET estado = 3
     WHERE cod_ent = v_cod_ent AND cod_fon = v_cod_fon AND fec_dat =
                                                                    v_fec_dat
           AND num_sol = v_num_sol;*/
    /*INSERT INTO eduardo
    VALUES      (TO_CHAR(v_num_sol) || ' ' || v_cod_ent || ' ' || v_cod_fon
                 || ' - ' || TO_CHAR(v_fec_dat, 'dd-mm-yyyy') || ' - '
                 || TO_CHAR(SYSDATE, 'HH24:MI:SS')
                );*/

    IF SQL%FOUND THEN
      COMMIT;
--insert into eduardo values ('final paso 3'); commit;
      BEGIN
        /* Cálculo de los Indicadores de riesgo Concentración de Cartera
           y Porcentaje de Cartera Valorada */
        menerr := 'Calculara perdida esperada...';
        p_calc_ppe(v_cod_ent, v_cod_fon, v_fec_dat);
--insert into eduardo values ('final paso 4'); commit;				
        menerr := 'Calculara indicador rendimiento ajustado...';
        IF v_cod_ent LIKE 'A%' THEN
          IF v_cod_fon NOT IN ('IP', 'IF') THEN
            u_ir_rend_ajustado(v_cod_ent, v_cod_fon, v_fec_dat);
          END IF;
        END IF;
--insert into eduardo values ('final paso 5'); commit;				
        /* Calculo de indicador de riesgo: rendimiento ajustado */
        /*IF ((vpcodopc IN ('A02', 'A03', 'A06', 'A07', 'A08', 'A09', 'A10', 'A11') AND
             pcodfon IN ('03', '05', '06', '07', '09', '10', '11', '18', '19', '23')
            ) OR
            (pcodopc = 'A04' AND pcodfon IN ('05', '06', '07', '11', '23'))
           )
        THEN
          BEGIN
            u_ir_rend_ajustado(pcodopc, pcodfon, pfecdat);
          EXCEPTION
            WHEN OTHERS
            THEN
              numerr := SQLCODE;

              INSERT INTO tg_exception
              VALUES      (pcodopc, pfecdat, pcodfon, pcodproi, v_num_sol,
                           'Error ' || TO_CHAR(numerr)
                           || 'al invocar U_IR_REND_AJUSTADO ' || pcodopc || ' '
                           || pcodfon || ' ' || TO_CHAR(pfecdat, 'dd-mm-yyyy')
                           || ' el ' || TO_CHAR(
                                          SYSDATE, 'yyyy/mm/dd hh24:mi:ss'
                                        ));
          END;
        END IF;*/
        menerr := 'Obtendrá fecha Anterior';
        SELECT MAX(fec_dat)
          INTO v_fec_ant
          FROM tg_bit
         WHERE cod_ent = v_cod_ent AND cod_fon = v_cod_fon
               AND fec_dat < v_fec_dat AND cod_pro IN ('83', '67') AND fin = 3;
--insert into eduardo values ('final paso 6'); commit;							 
        IF v_cod_fon NOT IN ('IP', 'IF') THEN
          -- Se comenta mientras se modifica el proceso
          menerr := 'Calculará Concentración';
          u_ir_concentracion(v_cod_ent, v_cod_fon, v_fec_dat);
--insert into eduardo values ('final paso 7'); commit;					
          menerr := 'Calculará Limites';
          -- Carga las alarmas
          /*IF    gv_pro_pre = '1'
             OR v_fec_dat <= TO_DATE ('30-06-2008', 'dd-mm-yyyy')
          THEN*/
          pr_k_limite.p_limite1(
            v_num_sol, v_fec_dat, v_cod_ent, v_cod_fon, 'S', 'S');
--insert into eduardo values ('final paso 8'); commit;						
          /*ELSE
             pr_k_limite_new.p_limite1 (
                v_num_sol,
                v_fec_dat,
                v_cod_ent,
                v_cod_fon,
                'S',
                'S'
             );
          END IF;*/

          DELETE      mv_rep_tmp
                WHERE num_sec = v_num_sol;
          menerr := 'Actualizará referencia';
          IF v_cod_ref IS NOT NULL THEN
            UPDATE tg_fon_ent
               SET cod_ref = v_cod_ref
             WHERE cod_ent = v_cod_ent AND cod_fon = v_cod_fon;
            IF SQL%FOUND THEN
              COMMIT;
            END IF;
          END IF;
--insert into eduardo values ('final paso 9'); commit;					
          -- debe procesar las alarmas 01
          IF v_cod_fon IN ('07', '18') THEN
            menerr := 'Procesará Alarma SFNV';
            FOR i IN c_mov_vm(v_cod_ent, v_cod_fon, v_fec_dat, v_fec_ant) LOOP
              /*IF    gv_pro_pre = '1'
                 OR v_fec_dat <= TO_DATE ('30-06-2008', 'dd-mm-yyyy')
              THEN*/
              pr_k_limite.ins_alarma_01(
                v_cod_ent, v_cod_fon, i.fec_dat, i.cod_ref, i.cod_emi,
                i.cod_ins, i.fec_ven, i.mar, i.met_val, i.cod_mod_inv,
                i.serie, i.cod_isin);
            /*ELSE
               pr_k_limite_new.ins_alarma_01 (
                  v_cod_ent,
                  v_cod_fon,
                  i.fec_dat,
                  i.cod_ref,
                  i.cod_emi,
                  i.cod_ins,
                  i.fec_ven,
                  i.mar,
                  i.met_val,
                  i.cod_mod_inv,
                  i.serie,
                  i.cod_isin
               );
            END IF;*/
            END LOOP;
          END IF;
--insert into eduardo values ('final paso 10'); commit;					
					--if v_fec_dat >= TO_DATE ('01-06-2014', 'dd-mm-yyyy') THEN
					--  menerr := 'Carga Precios';
					--	p_ins_vector(v_cod_ent, v_cod_fon, v_fec_dat);
					--end if;
					
        END IF;

        BEGIN
          SELECT val_par
            INTO v_env_ala
            FROM tg_par_gen
           WHERE cod_par = 'ENVALA';
        EXCEPTION
          WHEN OTHERS THEN
            v_env_ala := 'N';
        END;

        IF NVL(v_env_ala, 'N') = 'S' THEN
          menerr := 'Enviará correos';
          p_env_alarma(v_cod_ent, v_cod_fon, v_fec_dat);
        END IF;
--insert into eduardo values ('final paso 11'); commit;
        -- Se agrega para verificar los grupos de interes economico
        menerr := 'Verificará grupos de interes.';
        v_men := NULL;
        FOR i IN c_mov_vm(v_cod_ent, v_cod_fon, v_fec_dat, v_fec_ant) LOOP
          v_registros := 0;
          SELECT COUNT(1)
            INTO v_registros
            FROM tg_ent b, tg_emi c
           WHERE b.cod_ent = v_cod_ent AND c.cod_emi = i.cod_emi
                 AND b.cod_gru = c.cod_gru;
          IF NVL(v_registros, 0) > 0 THEN
            v_men := NVL(v_men, '') || 'Ent.' || v_cod_ent || ' fdo ' || v_cod_fon
                     || ' ' || 'Fec.' || TO_CHAR(v_fec_dat) || ' Emi ' || i.cod_emi
                     || ' ant ' || TO_CHAR(v_fec_ant) || ' ' || CHR(10) || CHR(
                                                                             13);
          END IF;
        END LOOP;
--insert into eduardo values ('final paso 12'); commit;        
/*insert into eduardo values('COrreos '||v_cod_ent||'-'||v_cod_fon||'-'||to_char(v_fec_dat)||
' '||v_men);*/
        IF  NVL(v_men, 'X') <> 'X' AND v_cod_fon <> 'IF' THEN
          p_env_correo(
            v_cod_ent, v_cod_fon, v_fec_dat,
            'Entidad ' || v_cod_ent || ' fdo ' || v_cod_fon
            || ' adquirió emisiones en su grupo.', v_men);
        END IF;
        menerr := 'Borrará tabla de procesos finales';
		    if substr(v_cod_ent,1,1) <> 'E' then
             DELETE      mv_pro_pen
             WHERE cod_ent = v_cod_ent AND cod_fon = v_cod_fon
             AND fec_dat = v_fec_dat AND num_sol = v_num_sol;
		    else
            DELETE      mv_pro_pen
            WHERE cod_ent = v_cod_ent --AND cod_fon = v_cod_fon
            AND fec_dat = v_fec_dat; --AND num_sol = v_num_sol;
		    end if;		
        COMMIT;
--insert into eduardo values ('final paso 13'); commit;				
        -- Se saco por que es un proceso global
        menerr := 'Calcular rentabilidad...';
        p_calc_renta;
--insert into eduardo values ('final paso 14'); commit;				
        menerr := 'Calcular rentabilidad RC...';
        p_calc_renta_rc;
        menerr := 'Calcular estadisticas para WEB...';
--insert into eduardo values ('final paso 15'); commit;				
		    if substr(v_cod_ent,1,1) = 'A' then
          p_calc_esta_web;
		    else
          p_calc_esta_web_rc;				
		    end if;
--insert into eduardo values ('final paso 16'); commit;				
		    -- Se agrega para que el sistema envie los recordatorios de cobro
--		    p_mens_cobro;
--insert into eduardo values ('final paso 17'); commit;				
		    --
      /*INSERT INTO eduardo
      VALUES      (TO_CHAR(v_num_sol) || ' ' || v_cod_ent || ' ' || v_cod_fon
                   || ' - ' || TO_CHAR(v_fec_dat, 'dd-mm-yyyy') || ' - '
                   || TO_CHAR(SYSDATE, 'HH24:MI:SS')
                  );
    update mv_pro_pen
  set estado = 3
    where cod_ent = v_cod_ent
  and cod_fon = v_cod_fon
  and fec_dat = v_fec_dat
  and num_sol = v_num_sol;*/
      EXCEPTION
        WHEN OTHERS THEN
          numerr := SQLCODE;
          menerr := menerr || ' - ' || SQLERRM;

          BEGIN
            enviar_correo(
              'supen_mensajeria@supen.fi.cr', 'oreamunoae@supen.fi.cr',
              'vargasqg@supen.fi.cr;rojasvi@supen.fi.cr;changkd@supen.fi.cr',
              'Error en procesos finales Sol ' || TO_CHAR(v_num_sol),
              v_cod_ent || '-' || v_cod_fon || '-' || TO_CHAR(v_fec_dat) || ' '
              || ' procesos finales ' || menerr || ' ' || TO_CHAR(numerr)
              || ' a las ' || TO_CHAR(SYSDATE, 'dd-mm-yyyy hh24:mi:ss') || '.');
          EXCEPTION
            WHEN OTHERS THEN
              INSERT INTO eduardo
                   VALUES (v_cod_ent || '-' || v_cod_fon || '-'
                           || TO_CHAR(v_fec_dat) || ' ' || ' procesos finales '
                           || menerr || ' ' || TO_CHAR(numerr) || ' a las '
                           || TO_CHAR(SYSDATE, 'dd-mm-yyyy hh24:mi:ss'));
          END;
          
		      if substr(v_cod_ent,1,1) <> 'E' then
            UPDATE mv_pro_pen
             SET estado = 4
            WHERE cod_ent = v_cod_ent AND cod_fon = v_cod_fon
                 AND fec_dat = v_fec_dat AND num_sol = v_num_sol;
		       else
             UPDATE mv_pro_pen
             SET estado = 4
             WHERE cod_ent = v_cod_ent --AND cod_fon = v_cod_fon
                 AND fec_dat = v_fec_dat; -- AND num_sol = v_num_sol;
		      end if;
					IF SQL%FOUND THEN
            COMMIT;
          END IF;
      END;
    END IF;
  END IF;
END;
/

