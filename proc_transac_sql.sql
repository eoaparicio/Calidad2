USE [BDSistInst]
GO
/****** Object:  StoredProcedure [SGP].[SP_Notificaciones]    Script Date: 27/06/2017 09:58:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [SGP].[SP_Notificaciones] 
AS 
BEGIN 
SET NOCOUNT ON; 
/****** Script para generacion de noificaciones del Sistema de Gestion de Personal ******/ 
/* Variables para cortes de control e internas */ 
 DECLARE @mensaje_ini varchar(max), 
 @mensaje_fin varchar(max), 
 @mensaje varchar(max), 
 @mail_asunto varchar(200), 
 @mail_rslt int, 
 @sep varchar(1), 
 @dir_correo varchar(5000), 
 @fec_ini as date, 
 @cod_usr varchar(50), 
 @fec_fin as date, 
 @plazoaviso int, 
 @dias_anticipo int,
 @server_mail varchar(50);
 
/* Variables para asignacion de los cursores */ 
 DECLARE @id_cap bigint, 
	@fec_iniStr varchar(25), 
	@fec_finStr varchar(25), 
	@nom_cur varchar(max), 
	@pagina varchar(200), 
	@link varchar(max), 
	@funcionario varchar(50); 
 
-- CREATE TABLE #TempCorreosGeneranotificaciones 
 --(Titulo varchar(200), dirCorreo varchar(200), Asunto varchar(200), Texto varchar(max)) 
 
 DECLARE @FechaNotif As datetime 
 SET @FechaNotif = (SELECT CONVERT(datetime,Valor,101) 
 FROM sgp.sgp_Parametro 
 WHERE Parametro = 'Notif_SGP') 
  
 set @server_mail = 'MailArtemisa'

 if convert(date,@FechaNotif) <= convert(date,dateadd(hour,-6,GETUTCDATE())) 
 Begin 
 
 -- Actualizar registrs pendientes de funcionarios que ya no están 
	update SGP.SGP_Cap_Fun 
	set nota = case when t1.nota is null then 0 else t1.nota end, 
		cap_apl = case when t1.cap_apl is null then 'S' else t1.cap_apl end, 
		fec_eva_apl = case when t1.fec_eva_apl is null then isnull(t1.fec_sal,getdate()) else t1.fec_eva_apl end, 
		com_pos_jef = case when t1.com_pos_jef is null then 'Func. se retiro de la institución' else t1.com_pos_jef end 
	from SGP.SGP_Cap_Fun t0, ( 
		select b.id_cap, b.ced_fun, 
			b.nota, cap_apl, b.fec_eva_apl, 
			f.fec_sal, b.com_pos_jef 
		FROM SGP.SGP_Cap_Cur AS a INNER JOIN 
			SGP.SGP_Cap_Fun AS b ON b.id_cap = a.id_cap INNER JOIN 
			SGP.SGP_Fun AS f ON b.ced_fun = f.Ced_fun 
		where a.int_ext in (1,2) --=@tipo 
		and a.est_cap = 2 
		and isnull(b.ausente,'N') = 'N' 
		and f.activo = 'N' 
		and ((b.nota is null and a.fec_fin + cast(sgp.f_dev_parametro('DiasMaximoEvaluacionIndividual') as int) < GETDATE()) 
		or (cap_apl is null and b.fec_eva_apl < GETDATE()))) t1 
	where t0.id_cap = t1.id_cap 
	and t0.ced_fun = t1.ced_fun 
 
 
	UPDATE sgp.sgp_Parametro 
	SET Valor = CONVERT(varchar,year(DATEADD(day,1,dateadd(hour,-6,GETUTCDATE())))) + '-' + 
		CONVERT(varchar,Month(DATEADD(day,1,dateadd(hour,-6,GETUTCDATE())))) + '-' + 
		CONVERT(varchar,day(DATEADD(day,1,dateadd(hour,-6,GETUTCDATE())))) 
	WHERE Parametro = 'Notif_SGP' 
 
	set @sep = CHAR(39); 
	set @mail_asunto = 'Inicio de inclusión de Necesidades de Formación'; 
	set @dir_correo = '' 
	set @mensaje ='' 
	set @pagina = 'https://si.supen.fi.cr/SGP/' 
 
	select @fec_ini=cast(valor as date) from sgp.SGP_Parametro 
	where Parametro = 'FechaInicioInclusiónNecesidades' 
 
	select @fec_fin=cast(valor as date) from sgp.SGP_Parametro 
	where Parametro = 'FechaFinalInclusiónNecesidades' 
 
	if dateadd(day,1,@fec_ini) = CONVERT(date,getdate()) 
	Begin 
		DECLARE correos_jefes CURSOR FOR 
			select d.[Login] 
			from SeguridadVES.SG_Departamentos a, SeguridadVES.SG_Usuarios c, SeguridadVES.SG_UsuariosEntidades d 
			where (a.CodigoDepartamento > 20) 
			and c.cedula = a.id_jefe 
			and d.codigousuario = c.codigousuario 
		OPEN correos_jefes; 
		FETCH NEXT FROM correos_jefes INTO @cod_usr 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			set @dir_correo = @dir_correo + @cod_usr+'@supen.fi.cr;' 
			FETCH NEXT FROM correos_jefes INTO @cod_usr 
		END 
		CLOSE correos_jefes 
		DEALLOCATE correos_jefes 
		--set @dir_correo = @dir_correo + 'oreamunoae@supen.fi.cr;' 
		select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
		where Parametro = 'CorreoAdministrador' 
		--print @dir_correo 
		if @dir_correo is not null 
		begin 
			set @mensaje = @mensaje + 'Se le informa que ha dado inicio el período de inclusión de NECESIDADES DE FORMACIÓN PARA EL PROXIMO AÑO,' 
			set @mensaje = @mensaje + ' como parte de las actividades requeridas para la determinación del presupuesto y de acuerdo con lo establecido en el procedimiento P PYC 02.<br/><br/>' 
 
			set @mensaje = @mensaje + 'Favor ajustarse al plazo comprendido entre el '+cast(@fec_ini as varchar)+' y el '+cast(@fec_fin as varchar)+' para el cumplimiento de esta solicitud.<br/><br/>' 
			--print @mensaje 
			set @mensaje = tramites.f_formatea_correo(@mensaje) 
			exec msdb.dbo.sp_send_dbmail @server_mail ,@dir_correo,'','',@mail_asunto, @mensaje, 
			 'HTML','NORMAL','NORMAL','','','',0,'''',1,256,' ',0,0,0,0,@mail_rslt,'',''; 
			--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
		end 
	END 
 
	set @mail_asunto = 'Fin de inclusión de Necesidades de Formación'; 
	set @dir_correo = '' 
	set @mensaje = '' 
	select @plazoaviso=cast(valor as int) from sgp.SGP_Parametro 
	where Parametro = 'AvisoDiasVenceNecesidades' 
 
	if dateadd(day,(@plazoaviso*-1),@fec_fin) = CONVERT(date,getdate()) 
	Begin 
		DECLARE correos_jefes CURSOR FOR 
			select d.[Login] 
			from SeguridadVES.SG_Departamentos a, SeguridadVES.SG_Usuarios c, SeguridadVES.SG_UsuariosEntidades d 
			where (a.CodigoDepartamento > 20) 
			and c.cedula = a.id_jefe 
			and d.codigousuario = c.codigousuario 
		OPEN correos_jefes; 
		FETCH NEXT FROM correos_jefes INTO @cod_usr 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			set @dir_correo = @dir_correo + @cod_usr+'@supen.fi.cr;' 
			FETCH NEXT FROM correos_jefes INTO @cod_usr 
		END 
		CLOSE correos_jefes 
		DEALLOCATE correos_jefes 
		-- set @dir_correo = @dir_correo + ''oreamunoae@supen.fi.cr;'' 
		select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
		where Parametro = 'CorreoAdministrador' 
		--print @dir_correo 
		if @dir_correo is not null 
		begin 
			set @mensaje = @mensaje + 'Se le informa que el '+cast(@fec_fin as varchar)+' vence el período de inclusión de NECESIDADES DE FORMACIÓN PARA EL PROXIMO AÑO,' 
			set @mensaje = @mensaje + ' como parte de las actividades requeridas para la determinación del presupuesto y de acuerdo con lo establecido en el procedimiento P PYC 02.<br/><br/>' 
			set @mensaje = @mensaje + 'Favor ajustarse al plazo comprendido entre el '+cast(@fec_ini as varchar)+' y el '+cast(@fec_fin as varchar)+' para el cumplimiento de esta solicitud.<br/><br/>' 
 
			set @mensaje = tramites.f_formatea_correo(@mensaje) 
			exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto, @mensaje, 
			 'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 
			--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
		end 
	END 
 
	set @mail_asunto = 'Evento de Capacitación'; 
	select @dias_anticipo=cast(valor as int)*-1 from sgp.SGP_Parametro 
	where Parametro = 'AvisoDiasInicioCurso' 
 
	/* Notificación de correos para aviso de evaluación individual al día */ 
	/* Cursor para los correos directos a cada usuario*/ 
	DECLARE correos_eval_indiv1 CURSOR FOR 
		select d.[Login], a.id_cap, a.nom_cur, 
			convert(varchar(10),a.fec_ini,103) as fec_ini, 
			convert(varchar(10),a.fec_fin,103) as fec_fin, 
			@pagina+'SGP_capacita_Detalle.aspx?id_cap='+cast(a.id_cap as nvarchar) link 
		from sgp.SGP_Cap_Cur a, sgp.SGP_Cap_Fun b, SeguridadVES.SG_Usuarios c, SeguridadVES.SG_UsuariosEntidades d 
		where a.int_ext = 2 and a.est_cap = 2 
		and convert(date,GETDATE()) between dateadd(day,@dias_anticipo,a.fec_ini) and convert(date,a.fec_ini) 
		and a.fec_ins is not null 
		and b.id_cap = a.id_cap 
		and isnull(b.ausente,'N') = 'N' and c.Cedula = b.ced_fun 
		and d.CodigoUsuario = c.CodigoUsuario and d.estado = 'A'; 
 
	OPEN correos_eval_indiv1; 
	FETCH NEXT FROM correos_eval_indiv1 
	INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		set @mensaje = 'Evento de capacitación: <b>'+@nom_cur+'</b><br/>' 
		set @mensaje = @mensaje + 'A Realizarse del '+@fec_iniStr+' al '+@fec_finStr+'<br/><br/>' 
		set @mensaje = @mensaje + '. <br /><br />' 
		set @mensaje = @mensaje + 'Le recordamos que dicho evento esta pronto a iniciar.<br />' 
		set @mensaje = @mensaje + 'Se le agradece considerar puntualidad, así como su compromiso de cumplir con el 100% de la actividad.' 
		set @mensaje = @mensaje + '<br/><br/><br/>' 
		set @mensaje = @mensaje + '<a href='+@sep+@link+@sep+' target='+@sep+'_blank'+@sep+' style='+@sep+'color:#2f81ac; text-decoration:underline;'+@sep+'>'+@link+'</a>'; 
		set @mensaje = @mensaje + '<br /><br />'; 
		set @dir_correo = @cod_usr+'@supen.fi.cr' 
		--set @dir_correo = @dir_correo + ';oreamunoae@supen.fi.cr;' 
		set @mensaje = tramites.f_formatea_correo(@mensaje) 
		exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto,@mensaje, 
		 'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 
		--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
		FETCH NEXT FROM correos_eval_indiv1 
		INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link 
	END 
	CLOSE correos_eval_indiv1; 
	DEALLOCATE correos_eval_indiv1; 
 
	set @mail_asunto = 'Evaluación Individual de Capacitación'; 
	/* Notificación de correos para aviso de evaluación individual al día */ 
	/* Cursor para los correos directos a cada usuario*/ 
	DECLARE correos_eval_indiv2 CURSOR FOR 
		select d.[Login], a.id_cap, a.nom_cur, 
			convert(varchar(10),a.fec_ini,103) as fec_ini, 
			convert(varchar(10),a.fec_fin,103) as fec_fin, 
			@pagina+'SGP_Eval_Ind.aspx?id_cap='+cast(a.id_cap as nvarchar) link 
		from sgp.SGP_Cap_Cur a, sgp.SGP_Cap_Fun b, SeguridadVES.SG_Usuarios c, SeguridadVES.SG_UsuariosEntidades d 
		where a.int_ext in (1,2) and a.est_cap = 2 
		and dateadd(day,1,a.fec_fin) = convert(date,GETDATE()) 
		and a.fec_ins is not null 
		and b.id_cap = a.id_cap 
		and isnull(b.ausente,'N') = 'N' 
		and c.Cedula = b.ced_fun 
		and b.ced_fun not in (select ced_fun from sgp.sgp_fun 
		where cod_pue in (select valor from sgp.sgp_parametro where parametro like 'Puesto%')) -- superintendente e intendente 
		--and activo = 'S') 
		and b.nota is null 
		and d.CodigoUsuario = c.CodigoUsuario and (d.estado = 'A'); -- and d.[login] not in ('ROBLESCE','AVILAVM')); 
	OPEN correos_eval_indiv2; 
	FETCH NEXT FROM correos_eval_indiv2 
	INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		set @mensaje = 'Evento de capacitación: <b>'+@nom_cur+'</b><br/>' 
		set @mensaje = @mensaje + 'Realizado del '+@fec_iniStr+' al '+@fec_finStr+'<br/><br/>' 
		set @mensaje = @mensaje + 'Favor completar la EVALUACIÓN INDIVIDUAL DE LA ACTIVIDAD DE CAPACITACIÓN,' 
		set @mensaje = @mensaje + ' en un plazo no mayor a 5 días hábiles. <u>Esta valoración es de aplicación obligatoria.</u><br/><br/>' 
		set @mensaje = @mensaje + 'En caso que corresponda: debe gestionar el envío de la copia del certificado de manera <b>digital</b> al Área de Comunicación y Servicios, en un plazo no mayor a 5 días hábiles, por trazabilidad y para su debida inclusión en el expediente académico electrónico del BCCR.'
		--set @mensaje = @mensaje + 'En caso que corresponda: debe hacer entrega de dos (2) copias del certificado respectivo al Área de Comunicación y Servicios.' 
		set @mensaje = @mensaje + '<br/><br/><br/>' 
		set @mensaje = @mensaje + '<a href='+@sep+@link+@sep+' target='+@sep+'_blank'+@sep+' style='+@sep+'color:#2f81ac; text-decoration:underline;'+@sep+'>'+@link+'</a>'; 
		set @mensaje = @mensaje + '<br /><br />'; 
		set @dir_correo = @cod_usr+'@supen.fi.cr' 
		set @dir_correo = @dir_correo + ';oreamunoae@supen.fi.cr;' 
		select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
		where Parametro = 'CorreoAdministrador' 
		set @mensaje = tramites.f_formatea_correo(@mensaje) 
		exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto,@mensaje, 
		 'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 
		--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
		FETCH NEXT FROM correos_eval_indiv2 
		INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link 
 END 
 CLOSE correos_eval_indiv2; 
 DEALLOCATE correos_eval_indiv2; 
 
 set @mail_asunto = 'Evaluación Individual de Capacitación Vencida'; 
 select @plazoaviso=cast(valor as int) from sgp.SGP_Parametro 
 where Parametro = 'DiasLimiteEvaluacion' 
 /* Notificación de correos para aviso de evaluación individual vencidos */ 
 /* Cursor para los correos directos a cada usuario*/ 
 DECLARE correos_eval_indiv3 CURSOR FOR 
	select d.[Login], a.id_cap, a.nom_cur, 
		convert(varchar(10),a.fec_ini,103) as fec_ini, 
		convert(varchar(10),a.fec_fin,103) as fec_fin, 
		@pagina+'SGP_Eval_Ind.aspx?id_cap='+cast(a.id_cap as nvarchar) link 
	from sgp.SGP_Cap_Cur a, sgp.SGP_Cap_Fun b, SeguridadVES.SG_Usuarios c, SeguridadVES.SG_UsuariosEntidades d 
	where a.int_ext in (1,2) and a.est_cap = 2 
	and dateadd(day,@plazoaviso,a.fec_fin) < convert(date,GETDATE()) 
	and a.fec_ins is not null 
	and b.id_cap = a.id_cap 
	and isnull(b.ausente,'N') = 'N' 
	and b.nota is null 
	and b.ced_fun not in (select ced_fun from sgp.sgp_fun 
	where cod_pue in (select valor from sgp.sgp_parametro
where parametro like 'Puesto%')) -- superintendente e intendente 
	--and activo = 'S') 
	and c.Cedula = b.ced_fun 
	and d.CodigoUsuario = c.CodigoUsuario and (d.estado = 'A'); -- and d.[login] not in ('ROBLESCE','AVILAVM')); 
	--and 0 < (select count(1) from SeguridadVES.SG_UsuariosRolesSistema 
	--where codigousuario = c.codigousuario 
	--and estado = 'A'); 
	OPEN correos_eval_indiv3; 
	FETCH NEXT FROM correos_eval_indiv3 
	INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		set @mensaje = 'Evento de capacitación: <b>'+@nom_cur+'</b><br/>' 
		set @mensaje = @mensaje + 'Realizado del '+@fec_iniStr+' al '+@fec_finStr+'<br/><br/>' 
		set @mensaje = @mensaje + 'Se le recuerda que se encuentra pendiente de efectuar la EVALUACIÓN INDIVIDUAL DE LA ACTIVIDAD DE CAPACITACIÓN.<br />' 
		set @mensaje = @mensaje + '<u>Esta valoración es de aplicación obligatoria.</u>' 
		set @mensaje = @mensaje + '<br/><br/><br/>' 
		set @mensaje = @mensaje + '<a href='+@sep+@link+@sep+' target='+@sep+'_blank'+@sep+' style='+@sep+'color:#2f81ac; text-decoration:underline;'+@sep+'>'+@link+'</a>'; 
		set @mensaje = @mensaje + '<br /><br />'; 
		set @dir_correo = @cod_usr+'@supen.fi.cr' 
		set @dir_correo = @dir_correo + ';oreamunoae@supen.fi.cr;' 
		select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
		where Parametro = 'CorreoAdministrador' 
		set @mensaje = tramites.f_formatea_correo(@mensaje) 
		exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto,@mensaje, 
		 'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 
		--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
		FETCH NEXT FROM correos_eval_indiv3 
		INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link 
	END 
	CLOSE correos_eval_indiv3; 
	DEALLOCATE correos_eval_indiv3; 
 
	set @mail_asunto = 'Evaluación Individual de Eficacia de Capacitación'; 
	/* Notificación de correos para aviso de evaluación de eficacia al día */ 
	/* Cursor para los correos directos a cada usuario*/ 
	DECLARE correos_eval_indiv4 CURSOR FOR 
		select d.[Login], a.id_cap, a.nom_cur, 
			convert(varchar(10),a.fec_ini,103) as fec_ini, 
			convert(varchar(10),a.fec_fin,103) as fec_fin, 
			@pagina+'SGP_Eval_Ind.aspx?id_cap='+cast(a.id_cap as nvarchar) link 
		from sgp.SGP_Cap_Cur a, sgp.SGP_Cap_Fun b, SeguridadVES.SG_Usuarios c, SeguridadVES.SG_UsuariosEntidades d 
		where a.int_ext = 2 and a.est_cap = 2 
		and convert(date,b.fec_eva_apl) = convert(date,GETDATE()) 
		and a.fec_ins is not null 
		and b.id_cap = a.id_cap 
		and isnull(b.ausente,'N') = 'N' 
		and isnull(b.cap_apl ,'N') <> 'S' 
		and b.jus_cap_apl is null 
		and b.ced_fun not in (select ced_fun from sgp.sgp_fun 
							  where cod_pue in (select valor from sgp.sgp_parametro
                                                where parametro like 'Puesto%')) -- superintendente e intendente 
		--and activo = 'S') 
		and c.Cedula = b.ced_fun 
		and d.CodigoUsuario = c.CodigoUsuario and (d.estado = 'A'); -- and d.[login] not in ('ROBLESCE','AVILAVM')); 
	OPEN correos_eval_indiv4; 
	FETCH NEXT FROM correos_eval_indiv4 
	INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		set @mensaje = 'Evento de capacitación: <b>'+@nom_cur+'</b><br/>' 
		set @mensaje = @mensaje + 'Realizado del '+@fec_iniStr+' al '+@fec_finStr+'<br/><br/>' 
		set @mensaje = @mensaje + 'Favor proceder con la EVALUACIÓN DE LA EFICACIA DE LA CAPACITACIÓN (aplicabilidad).<br/>' 
		set @mensaje = @mensaje + 'Ver detalle para consultar el evento de capacitación que corresponde ser evaluado.<br/><br/>' 
		set @mensaje = @mensaje + 'Se aclara que la información que se consigne es cierta y verificable, de conformidad con lo establecido en la legislación costarricense.' 
		set @mensaje = @mensaje + '<br/><br/><br/>' 
		set @mensaje = @mensaje + '<a href='+@sep+@link+@sep+' target='+@sep+'_blank'+@sep+' style='+@sep+'color:#2f81ac; text-decoration:underline;'+@sep+'>'+@link+'</a>'; 
		set @mensaje = @mensaje + '<br /><br />'; 
		set @dir_correo = @cod_usr+'@supen.fi.cr' 
		set @dir_correo = @dir_correo + ';oreamunoae@supen.fi.cr;' 
		select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
		where Parametro = 'CorreoAdministrador' 
		set @mensaje = tramites.f_formatea_correo(@mensaje) 
		exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto,@mensaje, 
		 'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 
		--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
		FETCH NEXT FROM correos_eval_indiv4 
		INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link 
	END 
	CLOSE correos_eval_indiv4; 
	DEALLOCATE correos_eval_indiv4; 
 
	select @plazoaviso=cast(valor as int) from sgp.SGP_Parametro 
	where Parametro = 'DiasLimiteEvaluacion'; 
 
	set @mail_asunto = 'Evaluación de eficacia pendiente'; 
	/* Notificación de correos para aviso de evaluación de eficacia vencidos */ 
	/* Cursor para los correos directos a cada usuario*/ 
	DECLARE correos_eval_indiv5 CURSOR FOR 
		select d.[Login], a.id_cap, a.nom_cur, 
			convert(varchar(10),a.fec_ini,103) as fec_ini, 
			convert(varchar(10),a.fec_fin,103) as fec_fin, 
			@pagina+'SGP_Eval_Ind.aspx?id_cap='+cast(a.id_cap as nvarchar) link 
		from sgp.SGP_Cap_Cur a, sgp.SGP_Cap_Fun b, SeguridadVES.SG_Usuarios c, SeguridadVES.SG_UsuariosEntidades d 
		where a.int_ext = 2 and a.est_cap = 2 
		and convert(date,dateadd(day,@plazoaviso,b.fec_eva_apl)) < convert(date,GETDATE()) 
		and a.fec_ins is not null 
		and b.id_cap = a.id_cap 
		and isnull(b.ausente,'N') = 'N' 
		and isnull(b.cap_apl ,'N') <> 'S' 
		and b.jus_cap_apl is null 
		and b.ced_fun not in (select ced_fun from sgp.sgp_fun 
							  where cod_pue in (select valor from sgp.sgp_parametro
                                                where parametro like 'Puesto%')) -- superintendente e intendente 
		--and activo = 'S') 
		and c.Cedula = b.ced_fun 
		and d.CodigoUsuario = c.CodigoUsuario and (d.estado = 'A'); -- and d.[login] not in ('ROBLESCE','AVILAVM')); 
		--and 0 < (select count(1) from SeguridadVES.SG_UsuariosRolesSistema 
		-- where codigousuario = c.codigousuario 
		-- and estado = 'A'); 
	OPEN correos_eval_indiv5; 
	FETCH NEXT FROM correos_eval_indiv5 
	INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		set @mensaje = 'Evento de capacitación: <b>'+@nom_cur+'</b><br/>' 
		set @mensaje = @mensaje + 'Realizado del '+@fec_iniStr+' al '+@fec_finStr+'<br/><br/>' 
		set @mensaje = @mensaje + 'Se le recuerda que se encuentra pendiente de efectuar la EVALUACIÓN DE LA EFICACIA DE LA CAPACITACIÓN (aplicabilidad).<br/>' 
		set @mensaje = @mensaje + 'Ver detalle para consultar el evento de capacitación que corresponde ser evaluado.<br/><br/>' 
		set @mensaje = @mensaje + 'Se aclara que la información que se consigne es cierta y verificable, de conformidad con lo establecido en la legislación costarricense.' 
		set @mensaje = @mensaje + '<br/><br/><br/>' 
		set @mensaje = @mensaje + '<a href='+@sep+@link+@sep+' target='+@sep+'_blank'+@sep+' style='+@sep+'color:#2f81ac; text-decoration:underline;'+@sep+'>'+@link+'</a>'; 
		set @mensaje = @mensaje + '<br /><br />'; 
		set @dir_correo = @cod_usr+'@supen.fi.cr' 
		set @dir_correo = @dir_correo + ';oreamunoae@supen.fi.cr;' 
		select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
		where Parametro = 'CorreoAdministrador' 
		set @mensaje = tramites.f_formatea_correo(@mensaje) 
 		exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto,@mensaje, 
		 'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 
		--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
		FETCH NEXT FROM correos_eval_indiv5 
		INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link 
	END 
	CLOSE correos_eval_indiv5; 
	DEALLOCATE correos_eval_indiv5; 
 
	set @mail_asunto = 'Evaluación de competencias pendiente por parte de los encargados '; 
	/* Notificación de correos para aviso de competencias vencidos */ 
 
	/* Variables para asignacion de los cursores */ 
	DECLARE @id_fun varchar(25), 
			@id_cmp int, 
			@int_ext int;
 
	 /* Cursor para los correos directos a cada usuario*/ 
	DECLARE correos_eval_indiv6 CURSOR FOR 
		select g.[Login], a.id_cap, a.nom_cur+'<FONT COLOR=''red''> ['+cmp.des_cmp+']</FONT>', 
			convert(varchar(10),a.fec_ini,103) as fec_ini, 
			convert(varchar(10),a.fec_fin,103) as fec_fin, 
			e.ced_eva, --sgp.f_dev_depto_sup_func(b.ced_fun), 
			c.nombre1+' '+c.apellido1+' '+c.apellido2 as cod_usuario, b.ced_fun, 
			b.cod_cmp, a.int_ext 
			--@pagina+'SGP_Eval_Ind.aspx?id_cap='+cast(a.id_cap as nvarchar) link 
		from sgp.SGP_Cap_Cur a, 
				sgp.SGP_Cap_Fun b, 
				SeguridadVES.SG_Usuarios c, 
				SeguridadVES.SG_UsuariosEntidades d, 
				sgp.sgp_cmp cmp, 
				sgp.SGP_Fun e, 
				SeguridadVES.SG_Usuarios f, 
				SeguridadVES.SG_UsuariosEntidades g 
		where a.int_ext in (1,2) and a.est_cap = 2  -- No comunica para cursos internos de competencias
		and a.are_cub = 2                           -- solo incluira una leyenda.
		and convert(date,dateadd(day,@plazoaviso,b.fec_eva_apl)) < convert(date,GETDATE()) 
		and a.fec_ins is not null 
		and b.id_cap = a.id_cap 
		and isnull(b.ausente,'N') = 'N' 
		and b.cod_cmp is not null 
		and b.com_pos_jef is null 
		and c.Cedula = b.ced_fun 
		and b.ced_fun not in (select ced_fun from sgp.sgp_fun 
							  where cod_pue in (select valor from sgp.sgp_parametro
                                                where parametro like 'Puesto%')) -- superintendente e intendente 
		and d.CodigoUsuario = c.CodigoUsuario 
		and d.estado = 'A' 
		and cmp.cod_cmp = b.cod_cmp 
		and b.ced_fun = e.ced_fun 
		and f.cedula = e.ced_eva 
		and g.codigousuario = f.codigousuario 
	OPEN correos_eval_indiv6; 
	FETCH NEXT FROM correos_eval_indiv6 
	INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link, @funcionario, @id_fun, @id_cmp, @int_ext
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
	-- Debe validar cursos internos de competencias para que incluya el comentario
	-- Validar si el funcionario tiene brecha 
	    if @int_ext = 1 
		begin
		  update sgp.SGP_Cap_fun 
		  set com_pos_jef = 'Formación Interna. No requiere calificación de competencia, únicamente evaluación individual.' 
		  where id_cap = @id_cap 
		  and ced_fun = @id_fun 
		end
		else
		begin
		  if (select count(1) from sgp.sgp_fun_cmp a, sgp.sgp_cmp_pto c 
			where a.ced_fun = @id_fun 
			and a.cod_cmp = @id_cmp 
			and a.fec_cmp = (select max(fec_cmp) from sgp.sgp_fun_cmp b 
											where b.ced_fun = a.ced_fun 
											and b.cod_cmp = a.cod_cmp) 
			and c.cod_pto = a.cod_pto 
			and c.cod_cmp = a.cod_cmp 
			and c.niv_des - a.niv_obt > 0) <= 0 
 
			update sgp.SGP_Cap_fun 
			set com_pos_jef = 'No tiene brecha en esta competencia' 
			where id_cap = @id_cap 
			and ced_fun = @id_fun 
		  else 
		  begin 
		  -- 
			set @mensaje = 'Evento de capacitación: <b>'+@nom_cur+'</b><br/>' 
			set @mensaje = @mensaje + 'Realizado del '+@fec_iniStr+' al '+@fec_finStr+'<br/><br/>' 
			set @mensaje = @mensaje + 'Se le recuerda que se encuentra pendiente de efectuar la EVALUACIÓN DE LA COMPETENCIA POR CAPACITACION' 
			set @mensaje = @mensaje + ' del funcionario '+@funcionario+'.<br/><br/>' 
			set @mensaje = @mensaje + 'Se aclara que la información que se consigne es cierta y verificable, de conformidad con lo establecido en la legislación costarricense.' 
			set @mensaje = @mensaje + '<br/><br/><br/>' 
			set @mensaje = @mensaje + '<br /><br />'; 
			set @mensaje = @mensaje + '<a href='+@sep+@pagina+'SGP_fun_Competencia.aspx'+@sep+' target='+@sep+'_blank'+@sep+' style='+@sep+'color:#2f81ac; text-decoration:underline;'+@sep+'>' 
					+@pagina+'SGP_fun_Competencia.aspx'+'</a>'; 
			set @dir_correo = @cod_usr+'@supen.fi.cr' 
			set @dir_correo = @dir_correo + ';oreamunoae@supen.fi.cr;' 
			select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
			where Parametro = 'CorreoAdministrador' 
			set @mensaje = tramites.f_formatea_correo(@mensaje) 
		    exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto,@mensaje, 
		      'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 
			--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
		  end 
		end
		FETCH NEXT FROM correos_eval_indiv6 
	    INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link, @funcionario, @id_fun, @id_cmp, @int_ext 
	END 
 
	CLOSE correos_eval_indiv6; 
	DEALLOCATE correos_eval_indiv6; 
 
	-- Validación de capacitaciones para funcionarios 
 
	set @mail_asunto = 'Validación de la eficacia efectuada por el colaborador';
	DECLARE correos_eval_indiv6 CURSOR FOR 
		select g.[Login], a.id_cap, a.nom_cur, 
			convert(varchar(10),a.fec_ini,103) as fec_ini, 
			convert(varchar(10),a.fec_fin,103) as fec_fin, 
			@pagina+'SGP_Eval_Ind.aspx?id_cap='+cast(a.id_cap as nvarchar) link, 
			c.nombre1+' '+c.apellido1+' '+c.apellido2 as cod_usuario, b.ced_fun 
		from sgp.SGP_Cap_Cur a, sgp.SGP_Cap_Fun b, SeguridadVES.SG_Usuarios c, SeguridadVES.SG_UsuariosEntidades d, 
			sgp.SGP_Fun e, SeguridadVES.SG_Usuarios f, SeguridadVES.SG_UsuariosEntidades g 
		where a.int_ext in (2) and a.est_cap = 2 
		and a.are_cub <> 2 
		--and convert(date,dateadd(day,5,b.fec_eva_apl)) < convert(date,GETDATE()) 
		and convert(date,dateadd(day,@plazoaviso,b.fec_eva_apl)) < convert(date,GETDATE()) 
		and a.fec_ins is not null 
		and b.id_cap = a.id_cap 
		and isnull(b.ausente,'N') = 'N' 
		and b.com_pos_jef is null 
		and c.Cedula = b.ced_fun 
		and d.CodigoUsuario = c.CodigoUsuario 
		and d.estado = 'A' 
		--and e.codigodepartamento = sgp.f_dev_depto_sup_func(b.ced_fun) 
		and b.ced_fun = e.ced_fun 
		and f.cedula = e.ced_eva 
		and g.codigousuario = f.codigousuario 
		--and f.cedula = e.id_jefe 
		--and g.codigousuario = f.codigousuario 
		and ( 
			(b.nota is not null) AND 
			(b.cap_apl is not null)) 
		and a.fec_ini > '20150101' -- por requerimiento de danisella. 
 
	OPEN correos_eval_indiv6; 
	FETCH NEXT FROM correos_eval_indiv6 
	INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr, @fec_finStr, @link, @funcionario, @id_fun --, @id_cmp 
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
	-- 
		set @mensaje = 'Evento de capacitación: <b>'+@nom_cur+'</b><br/>' 
		set @mensaje = @mensaje + 'Realizado del '+@fec_iniStr+' al '+@fec_finStr+'<br/><br/>' 
		set @mensaje = @mensaje + 'Se le recuerda que se encuentra pendiente de VALIDAR la EVALUACION DE LA EFICACIA realizada por el'
		set @mensaje = @mensaje + ' colaborador '+@funcionario+'.<br/><br/>' 
		set @mensaje = @mensaje + 'Se aclara que la información que se consigne es cierta y verificable, de conformidad con lo establecido en la legislación costarricense.' 
		set @mensaje = @mensaje + '<br/><br/><br/>' 
		set @mensaje = @mensaje + '<br /><br />'; 
		set @mensaje = @mensaje + '<a href='+@sep+@link+@sep+' target='+@sep+'_blank'+@sep+' style='+@sep+'color:#2f81ac; text-decoration:underline;'+@sep+'>'+@link+'</a>'; 
		set @dir_correo = @cod_usr+'@supen.fi.cr' 
		set @dir_correo = @dir_correo + ';oreamunoae@supen.fi.cr;' 
		select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
		where Parametro = 'CorreoAdministrador' 
		set @mensaje = tramites.f_formatea_correo(@mensaje) 
		exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto,@mensaje, 
		 'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 

		--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
		FETCH NEXT FROM correos_eval_indiv6 
		INTO @cod_usr, @id_cap, @nom_cur, @fec_iniStr,@fec_finStr, @link, @funcionario, @id_fun --, @id_cmp 
	END 
 
	CLOSE correos_eval_indiv6; 
	DEALLOCATE correos_eval_indiv6; 
 
	-- Mensajes de evaluación de brechas 
	--if datepart(mm,getdate()) = cast(sgp.f_dev_parametro('MesGradoCompetencia') as int) 
	--Begin 
		set @mail_asunto = 'Calificación de las brechas en las competencias de los funcionarios'; 
		/* Notificación de correos para aviso de evaluación de brechas */ 
		/* Cursor para los correos directos a cada usuario*/ 
		DECLARE correos_eval_indiv6 CURSOR FOR 
			select distinct g.[Login], 
				'['+cmp.des_cmp+']', 
				c.nombre1+' '+c.apellido1+' '+c.apellido2 as cod_usuario
			from sgp.SGP_Cap_Cur a, 
					sgp.SGP_Cap_Fun b, 
					SeguridadVES.SG_Usuarios c, 
					SeguridadVES.SG_UsuariosEntidades d, 
					sgp.SGP_Fun e, 
					SeguridadVES.SG_Usuarios f, 
					SeguridadVES.SG_UsuariosEntidades g, 
					sgp.sgp_cmp cmp, 
				(select a1.cod_cmp, a1.ced_fun from sgp.sgp_fun_cmp a1, sgp.sgp_cmp_pto c1 
					where /*a1.ced_fun = b.ced_fun --'0107980956' ---@id_fun 
								and a1.cod_cmp = b.cod_cmp 
					and*/ a1.fec_cmp = (select max(b1.fec_cmp) from sgp.sgp_fun_cmp b1 
															where b1.ced_fun = a1.ced_fun 
															and b1.cod_cmp = a1.cod_cmp) 
					and c1.cod_pto = a1.cod_pto 
					and c1.cod_cmp = a1.cod_cmp 
					and c1.niv_des - a1.niv_obt > 0 
					and a1.niv_jef is null) ev_cmp 
			where a.int_ext in (2) and a.est_cap = 2 -- No comunica para cursos internos de competencias
			and a.are_cub = 2 
			and a.fec_ini > (select max(b2.fec_cmp) from sgp.sgp_fun_cmp b2 
							 where b2.ced_fun = b.ced_fun) 
			and b.id_cap = a.id_cap 
			and isnull(b.ausente,'N') = 'N' 
			and b.cod_cmp is not null 
			and b.com_pos_jef is not null 
			and c.Cedula = b.ced_fun 
			and d.CodigoUsuario = c.CodigoUsuario 
			and d.estado = 'A' 
			and e.activo = 'S'
			--and e.codigodepartamento = sgp.f_dev_depto_sup_func(b.ced_fun) 
			--and f.cedula = e.id_jefe 
			--and g.codigousuario = f.codigousuario 
			and b.ced_fun = e.ced_fun 
			and f.cedula = e.ced_eva 
			and g.codigousuario = f.codigousuario 
			and cmp.cod_cmp = b.cod_cmp 
			and ev_cmp.cod_cmp = b.cod_cmp 
			and ev_cmp.ced_fun = b.ced_fun 
			and b.fec_eva_apl < CONVERT(DATETIME, (CONVERT(VARCHAR, YEAR(DATEADD(hour,-6,GETUTCDATE()))) + '-' + sgp.f_dev_parametro('MesGradoCompetencia') + '-' + '01'), 101) --getdate() 
			-- Se cambia para que los atrasados sigan llegando.
			--and b.fec_eva_apl < getdate() 
 
		OPEN correos_eval_indiv6; 
		FETCH NEXT FROM correos_eval_indiv6 
		INTO @cod_usr, 
		 @nom_cur, -- competencia 
		 @funcionario -- Nombre 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
		-- 
			set @mensaje = 'Calificación de Brechas de la competencia <b>'+@nom_cur+'</b><br/>' 
			set @mensaje = @mensaje + 'Realizado en el período anterior '+'<br/><br/>' --del '+@fec_iniStr+' al '+@fec_finStr 
			set @mensaje = @mensaje + 'Se le recuerda que se encuentra pendiente de efectuar la CALIFICACION DE LA BRECHA EN LA COMPETENCIA ' 
			set @mensaje = @mensaje + ' del funcionario '+@funcionario+'.<br/><br/>' 
			set @mensaje = @mensaje + 'Se aclara que la información que se consigne es cierta y verificable, de conformidad con lo establecido en la legislación costarricense.' 
			set @mensaje = @mensaje + '<br/><br/><br/>' 
			set @mensaje = @mensaje + '<br /><br />'; 
			set @mensaje = @mensaje + '<a href='+@sep+@pagina+'SGP_fun_Competencia.aspx'+@sep+' target='+@sep+'_blank'+@sep+' style='+@sep+'color:#2f81ac; text-decoration:underline;'+@sep+'>' 
				+@pagina+'SGP_fun_Competencia.aspx'+'</a>'; 
			set @dir_correo = @cod_usr+'@supen.fi.cr' 
			set @dir_correo = @dir_correo + ';oreamunoae@supen.fi.cr;' 
			select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
			where Parametro = 'CorreoAdministrador' 
			set @mensaje = tramites.f_formatea_correo(@mensaje) 
		    exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto,@mensaje, 
		      'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 

			--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
			FETCH NEXT FROM correos_eval_indiv6 
			INTO @cod_usr, 
					 @nom_cur, -- competencia 
					 @funcionario -- Nombre 
		END 
 
		CLOSE correos_eval_indiv6; 
		DEALLOCATE correos_eval_indiv6; 
	--END 
		-- Hasta aqui 
	declare @v_year_ini int 
	set @v_year_ini = datepart(year,getdate()) 
	if datepart(mm,getdate()) = 1 
	  set @v_year_ini = (datepart(year,getdate())-1) 
	
	--declare @v_fec_proc date
	--set @v_fec_proc = getdate()

 -- hay que modificar para que no lo haga para una fecha fija si no para el primer día habil de cada mes
    if datepart(mm,getdate()) in (4,7,10,1) 
	begin 
	if datepart(dd,getdate()) <= 3 
	begin 
	    if datepart(dw,getdate()) = 2 -- Si es u lunes que procese
		Begin
		declare @sgp_notif table 
			(cod_dep int, cod_tem int, cod_sub_tem int, can_fun int, can_fun_cap int) 
 
		insert into @sgp_notif 
		select a1.depto, a1.cod_tem_cap, a1.cod_sub_tem_cap, COUNT(1), null 
		from (select d.id_nec_for,sgp.f_dev_depto_sup_func(d.ced_fun) depto, c.cod_tem_cap, c.cod_sub_tem_cap 
						from sgp.SGP_Nec_For c, sgp.SGP_Nec_for_Dep d 
						where d.id_nec_for = c.id_nec_for 
						and c.est_nec = 'A' 
						and c.fec_apr is not null 
						and d.id_nec_for between @v_year_ini*10000 and ((@v_year_ini*10000)+9999)) as a1 
		group by a1.depto, a1.cod_tem_cap, a1.cod_sub_tem_cap 
 
		update @sgp_notif 
		set can_fun_cap = a2.reg 
		from (select a1.depto, a1.cod_tem_cap, a1.cod_sub_tem_cap, COUNT(1) as reg              
         from (select sgp.f_dev_depto_sup_func(d1.ced_fun) depto, d1.cod_tem_cap, d1.cod_sub_tem_cap
               from (select distinct d.ced_fun, c.cod_tem_cap,c.cod_sub_tem_cap
                     from sgp.SGP_Cap_Cur b, sgp.SGP_Nec_For c, sgp.SGP_Cap_Fun d              
                     where b.fec_ini between convert(date,convert(varchar,@v_year_ini)+'0101') and getdate()
                     and b.int_ext = 2 and b.est_cap = 2              
                     -- se agrega por help desk del 30-07-2014        
                     and b.tip_cap not in (20)  
                     and (b.obj_cap not like 'Inclusión de capacitación sin costo' and   
                          b.obj_cap not like 'Inclusión de capacitación previa')           
                     --        
                     and c.est_nec = 'A'  
                     and isnull(d.ausente,'N') ='N'            
                     and b.id_nec_for is not null              
                     and c.id_nec_for = b.id_nec_for               
                     and d.id_cap = b.id_cap 
					 ) as d1
				) as a1              
         group by a1.depto, a1.cod_tem_cap, a1.cod_sub_tem_cap) as a2 
		where cod_dep = a2.depto and cod_tem = a2.cod_tem_cap 
		and isnull(cod_sub_tem,0) = isnull(a2.cod_sub_tem_cap,0) 
 
		declare @v_jefe_aux varchar(30) 
		set @v_jefe_aux = 'NINGUNO' 
		set @mensaje = null 
		set @mail_asunto = '<-- Resumen de necesidades de formación -->'; 
		DECLARE correos_eval_indiv7 CURSOR FOR 
			select c.des_tem_cap + 
				case isnull(d.des_sub_tem_cap,'X') 
					when 'X' then '' 
					else ' / Subtema:'+ d.des_sub_tem_cap 
					end AS 'Tema', 
					a.can_fun, 
					isnull(a.can_fun_cap,0) as can_fun_cap, 
					convert(integer,round((isnull(convert(money,can_fun_cap),0) / convert(money,can_fun))*100,0)) as result, 
					g.[login] 
			FROM @sgp_notif AS a INNER JOIN 
					SGP.SGP_Tem_Cap AS c ON a.cod_tem = c.cod_tem_cap LEFT OUTER JOIN 
					SGP.SGP_Sub_Tem_Cap AS d ON a.cod_tem = d.cod_tem_cap AND a.cod_sub_tem = d.cod_sub_tem_cap INNER JOIN 
					seguridadves.sg_departamentos as e on a.cod_dep = e.codigodepartamento INNER JOIN 
					SeguridadVES.SG_Usuarios as f on e.id_jefe = f.cedula INNER JOIN 
					SeguridadVES.SG_UsuariosEntidades as g on f.codigousuario = g.codigousuario 
			order by a.cod_dep, a.cod_tem, a.cod_sub_tem 
		OPEN correos_eval_indiv7; 
		FETCH NEXT FROM correos_eval_indiv7 
		INTO @link, -- se usara para el tema 
				@fec_iniStr, -- se usa para cant de func neces 
				@fec_finStr, -- se usa para cant de func capac 
				@funcionario, -- % de capacitaciones ejecutadas 
				@cod_usr 
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			if @v_jefe_aux <> @cod_usr 
			begin 
				--print isnull(@mensaje,'X') 
				if isnull(@mensaje,'X') <> 'X' 
				begin 
					set @mensaje = @mensaje+'</table>' 
					set @mensaje = @mensaje + '<br/><br/><br/>Se le recuerda la importancia de efectuar una adecuada ejecución de la capacitación, de acuerdo con lo propuesto originalmente en el Plan.<br/><br/><br/>' 
					set @mensaje = @mensaje + '<br /><br />'; 
					set @dir_correo = @v_jefe_aux+'@supen.fi.cr' 
					set @dir_correo = @dir_correo + ';oreamunoae@supen.fi.cr;' 
					select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
					where Parametro = 'CorreoAdministrador' 
					set @mensaje = tramites.f_formatea_correo(@mensaje) 
		            exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto,@mensaje, 
		              'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 
					--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
 				end 
				
				set @v_jefe_aux = @cod_usr 
				set @mensaje = '<b>NECESIDADES DE FORMACION SOLICITADAS</b><br/><br/>' --' +@link+' 
				set @mensaje = @mensaje+'De acuerdo con las necesidades propuestas y según lo aprobado en el Plan de Capacitación Institucional,<br/>' 
				set @mensaje = @mensaje+'adjunto encontrará un detalle de los temas sobre los que se ha recibido formación en el proceso a su cargo,<br/>' 
				set @mensaje = @mensaje+'así como, sobre los temas pendientes de programar (ejecución 0%).<br/><br/>' 
				set @mensaje = @mensaje+'La frecuencia de remisión de estas alertas es trimestral, a efecto de que cada período pueda visualizar el acumulado de lo ejecutado por tema.<br/><br/>' 
				set @mensaje = @mensaje+'<table>' 
				set @mensaje = @mensaje+'<tr>' 
				set @mensaje = @mensaje+'<td ALIGN=CENTER>Tema/Subtema</td>' 
				set @mensaje = @mensaje+'<td ALIGN=CENTER>Funcionarios propuestos</td>' 
				set @mensaje = @mensaje+'<td ALIGN=CENTER>Funcionarios capacitados</td>' 
				set @mensaje = @mensaje+'<td ALIGN=CENTER>%</td>' 
				set @mensaje = @mensaje+'</tr>' 
			end 
			set @mensaje = @mensaje+'<tr>' 
			set @mensaje = @mensaje+'<td>'+@link+'</td>' 
			set @mensaje = @mensaje+'<td ALIGN=CENTER>'+@fec_iniStr+'</td>' 
			set @mensaje = @mensaje+'<td ALIGN=CENTER>'+@fec_finStr+'</td>' 
			set @mensaje = @mensaje+'<td ALIGN=RIGHT>'+@funcionario+'%</td>' 
			set @mensaje = @mensaje+'</tr>' 
 
		FETCH NEXT FROM correos_eval_indiv7 
		INTO @link, -- se usara para el tema 
					@fec_iniStr, -- se usa para cant de func neces 
					@fec_finStr, -- se usa para cant de func capac 
					@funcionario, -- % de capacitaciones ejecutadas 
					@cod_usr 
		END 
	-- Guarda el último registro 
		if isnull(@mensaje,'X') <> 'X' 
		begin 
			set @mensaje = @mensaje+'</table>' 
			set @mensaje = @mensaje + '<br/><br/><br/>Se le recuerda la importancia de efectuar una adecuada ejecución de la capacitación, de acuerdo con lo propuesto originalmente en el Plan.<br/><br/><br/>' 
			set @mensaje = @mensaje + '<br /><br />'; 
			set @dir_correo = @v_jefe_aux+'@supen.fi.cr' 
			set @dir_correo = @dir_correo + ';oreamunoae@supen.fi.cr;' 
			select @dir_correo=@dir_correo+valor+'@supen.fi.cr' from sgp.SGP_Parametro 
			where Parametro = 'CorreoAdministrador' 
			set @mensaje = tramites.f_formatea_correo(@mensaje) 
		    exec msdb.dbo.sp_send_dbmail @server_mail,@dir_correo,'','',@mail_asunto,@mensaje, 
		      'HTML','NORMAL','NORMAL','','','',0,'',1,256,' ',0,0,0,0,@mail_rslt,'',''; 

			--INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa',@dir_correo,@mail_asunto, @mensaje; 
		end 
 
		CLOSE correos_eval_indiv7; 
		DEALLOCATE correos_eval_indiv7; 
		end
	end 
    end
end -- del if 
 --else 
 -- INSERT INTO #TempCorreosGeneranotificaciones SELECT 'MailArtemisa','oreamunoae@supen.fi.cr','SGP - Sin notificaciones', 'No generó notificaciones SGP'; 
 
--Select * From #TempCorreosGeneranotificaciones 
--delete #TempCorreosGeneranotificaciones 
 
end