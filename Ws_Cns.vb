Imports System.Web
Imports System.Web.Services
Imports System.Web.Services.Protocols
Imports System.Data.SqlClient
Imports System.Data
Imports System.Collections.Generic

<WebService(Namespace:="http://tempuri.org/")> _
<WebServiceBinding(ConformsTo:=WsiProfiles.BasicProfile1_1)> _
<Global.Microsoft.VisualBasic.CompilerServices.DesignerGenerated()> _
Public Class Ws_Cns
   Inherits System.Web.Services.WebService
   Protected SQLCmd As SqlCommand
   Protected SQLConn As SqlConnection
   Protected SQLAdapter As SqlDataAdapter
   Protected StrConn As String = ConfigurationManager.ConnectionStrings("CNS_ConnStr").ToString
   Friend DS As New DataSet
   Protected MkChr As String = Chr(255)
   'variables requeridas para el manejo del catalogo de indexado
   Protected LocalConn As ConnectionStringSettings
   Protected MyConn As System.Data.OleDb.OleDbConnection
   <WebMethod()> _
   Public Function Buscar_Catalogo(ByVal pTConse As String, ByVal pTexto As String, ByVal Tipo As Integer) As Data.DataSet
      'esta es la funcion de lectura del catalogo de indexado
      Dim DTR As DataTableReader, strSQL As String, wkStr As String

      If Tipo = 0 Then
         LocalConn = ConfigurationManager.ConnectionStrings("CNS_IndexConnStr")
      Else
         LocalConn = ConfigurationManager.ConnectionStrings("CNS_IndexHistoConnStr")
      End If
      MyConn = New System.Data.OleDb.OleDbConnection(LocalConn.ConnectionString)

      strSQL = "Select DocTitle,Filename,Size,PATH,URL from SCOPE()" & _
         " where FREETEXT('" & pTexto & "')"

      Dim cmdAux As New System.Data.OleDb.OleDbDataAdapter(strSQL, MyConn)
      Dim filesDataSet As New DataSet()

      cmdAux.Fill(filesDataSet)
      DTR = filesDataSet.CreateDataReader
      'por cada archivo encontrado, genera un registro con el consecutivo
      'dueño del mismo

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Conse"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      Dim LocalDS As New DataSet

      Dim Lst As New ListBox

      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         LocalDS.Reset()
         LocalDS = Get_ConsexArchivo(pTConse, DTR.GetString(1))
         'el ordinal del FileName es 1
         If LocalDS.Tables(0).Rows.Count > 0 Then
            'puede encontrar el texto en archivos de los otros consecutivos
            'por eso se agregó este IF

            'ademas, un mismo consecutivo puede tener varios archivos y, estos
            'cumplir con la búsqueda, pero el consecutivo debe ser mencionado
            'una sola vez
            wkStr = LocalDS.Tables(0).Rows(0)(0)

            Dim It As New ListItem
            It.Text = wkStr
            It.Value = wkStr

            If Not (Lst.Items.Contains(It)) Then
               workRow("Conse") = wkStr
               dataset.Tables(0).Rows.Add(workRow)
               Lst.Items.Add(wkStr)
            End If
         End If
      End While

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
      Public Function Sig_Consecutivo(ByVal pConse As String, ByVal pYear As String) As DataSet

      'según el tipo de consecutivo
      'se reinicia al principio de año

      Call Prepara_Comando("Get_Tipo_Reinicio")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      If DS.Tables(0).Rows(0)(0) = "N" Then 'no posee reinicio anual
         Call Prepara_Comando("Calcula_Consecutivo_NoYear")
         SQLCmd.Parameters.Add(par_Conse)
      Else
         Call Prepara_Comando("Calcula_Consecutivo")
         SQLCmd.Parameters.Add(par_Conse)

         Dim par_Year As SqlParameter = New SqlParameter("@Year", SqlDbType.VarChar)
         par_Year.Value = pYear
         SQLCmd.Parameters.Add(par_Year)
      End If

      DS.Reset()
      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)

   End Function
   <WebMethod()> _
      Public Function Sig_Destinatario() As String
      Dim DTR As Data.DataTableReader, sWork As String

      Call Prepara_Comando("Calcula_CodDestinatario")

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()
      DTR = DS.CreateDataReader
      DTR.Read()
      If DTR.HasRows Then
         sWork = "0" & CStr(DTR.GetValue(DTR.GetOrdinal("Nuevo")))
      Else
         sWork = "01"
      End If

      Return sWork

   End Function
   <WebMethod()> _
     Public Function Sig_Institucion() As String
      Dim DTR As Data.DataTableReader, sWork As String

      Call Prepara_Comando("Calcula_CodInst")

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()
      DTR = DS.CreateDataReader
      DTR.Read()
      If DTR.HasRows Then
         sWork = "0" & CStr(DTR.GetValue(DTR.GetOrdinal("Nuevo")))
      Else
         sWork = "01"
      End If

      Return sWork

   End Function
   <WebMethod()> _
     Public Function Sig_Tema() As String
      Dim DTR As Data.DataTableReader, sWork As String

      Call Prepara_Comando("Calcula_CodTema")

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()
      DTR = DS.CreateDataReader
      DTR.Read()
      If DTR.HasRows Then
         sWork = "0" & CStr(DTR.GetValue(DTR.GetOrdinal("Nuevo")))
      Else
         sWork = "01"
      End If

      Return sWork

   End Function
   <WebMethod()> _
   Public Function Get_Dir_Anexos() As DataSet

      Call Prepara_Comando("Get_Dir_Anexos")

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
      Public Function Descrip_Consecutivo(ByVal pConse As String) As String

      Call Prepara_Comando("Get_Def_Consec")
      
      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader
      DTR.Read()
      Dim s As String
      s = DTR.GetString(0)
      Return s

   End Function
   <WebMethod()> _
      Public Function Get_Confidencialidad(ByVal pTConse As String, ByVal pConse As String) As String

      Call Prepara_Comando("Get_Tipo_Confi")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      Dim par_Year As SqlParameter = New SqlParameter("@pAño", SqlDbType.VarChar)
      par_Year.Value = pConse.Substring(0, 4)
      SQLCmd.Parameters.Add(par_Year)

      Dim par_Num As SqlParameter = New SqlParameter("@pNum", SqlDbType.VarChar)
      par_Num.Value = pConse.Substring(5)
      SQLCmd.Parameters.Add(par_Num)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader
      DTR.Read()

      Dim s As String
      If DTR.HasRows Then
         s = DTR.GetString(0)
      Else
         s = "N"
      End If
      Return s

   End Function
   <WebMethod()> _
      Public Function Nombre_Destinatario(ByVal pCodDest As String) As String

      Call Prepara_Comando("Get_Nombre_Dest")

      Dim par_Conse As SqlParameter = New SqlParameter("@Cod_Dest", SqlDbType.VarChar)
      par_Conse.Value = pCodDest
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader
      DTR.Read()
      Dim s As String
      s = DTR.GetString(0)
      Return s

   End Function
   <WebMethod()> _
      Public Function Codigo_Institucion(ByVal pNombre As String) As String

      Call Prepara_Comando("Get_Codigo_Inst")

      Dim par_Nombre As SqlParameter = New SqlParameter("@pNombre", SqlDbType.VarChar)
      par_Nombre.Value = pNombre
      SQLCmd.Parameters.Add(par_Nombre)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader
      Dim s As String
      If DTR.HasRows Then
         DTR.Read()
         s = DTR.GetString(0)
      Else
         s = ""
      End If
      Return s

   End Function
   <WebMethod()> _
   Public Function Get_ConsexArchivo(ByVal pTConse As String, ByVal pArchivo As String) As DataSet

      Call Prepara_Comando("Get_ConsexArchivo")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      Dim par_Archivo As SqlParameter = New SqlParameter("@pArchivo", SqlDbType.VarChar)
      par_Archivo.Value = pArchivo
      SQLCmd.Parameters.Add(par_Archivo)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function ObtieneInstituciones() As Data.DataSet

      Call Prepara_Comando("Get_Instituciones")

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function ObtieneAños(ByVal pConse As String) As Data.DataSet

      Call Prepara_Comando("Get_Distinct_Años")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      'se refiere a los años existentes, hay que agregar un item en blanco
      'para las búsquedas
      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Año"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      workRow("Año") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)

      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         workRow("Año") = DTR.GetValue(DTR.GetOrdinal("Año"))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function ObtieneAños_Histo(ByVal pConse As String) As Data.DataSet

      Call Prepara_Comando("Get_Distinct_Años_Histo")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      'se refiere a los años existentes, hay que agregar un item en blanco
      'para las búsquedas
      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Año"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      workRow("Año") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)

      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         workRow("Año") = DTR.GetValue(DTR.GetOrdinal("Año"))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function ObtieneDestinatarios(ByVal pInsti As String) As Data.DataSet

      Call Prepara_Comando("Get_DestinatariosxInst")

      Dim par_Inst As SqlParameter = New SqlParameter("@pInsti", SqlDbType.VarChar)
      par_Inst.Value = pInsti
      SQLCmd.Parameters.Add(par_Inst)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function Lista_Destinatarios(ByVal pInsti As String) As Data.DataSet

      Call Prepara_Comando("List_DestinatariosxInst")

      Dim par_Inst As SqlParameter = New SqlParameter("@pInsti", SqlDbType.VarChar)
      par_Inst.Value = pInsti
      SQLCmd.Parameters.Add(par_Inst)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function Hay_Codigos_Ligados(ByVal pTipoCod As String, ByVal pValor As String) As Boolean
      Dim DTR As Data.DataTableReader, Rslt As Boolean

      Call Prepara_Comando("Codigos_Ligados")

      Dim par_Tipo As SqlParameter = New SqlParameter("@pTipoCod", SqlDbType.VarChar)
      par_Tipo.Value = pTipoCod
      SQLCmd.Parameters.Add(par_Tipo)

      Dim par_Valor As SqlParameter = New SqlParameter("@pCodigo", SqlDbType.VarChar)
      par_Valor.Value = pValor
      SQLCmd.Parameters.Add(par_Valor)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)
      DTR = DS.CreateDataReader

      Call Cierra_Conexion()
      DTR.Read()
      Rslt = (DTR.GetValue(DTR.GetOrdinal("Total")) > 0)

      Return (Rslt)
   End Function
   <WebMethod()> _
   Public Function ObtieneCategorias() As Data.DataSet

      Call Prepara_Comando("Get_Categorias")

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

     Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function ObtieneTemas() As Data.DataSet

      Call Prepara_Comando("Get_Temas")

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
  Public Function Get_Parametros() As Data.DataSet

      Call Prepara_Comando("Get_Params")

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function Mantenimiento_Temas(ByVal pActivo As String) As Data.DataSet

      Call Prepara_Comando("Mant_Temas")

      'El store procedure funciona por exclusion, asi que aqui se hace la conversion necesaria
      pActivo = pActivo.ToUpper
      Select Case pActivo
         Case "S"
            pActivo = "N"
            Exit Select
         Case "N"
            pActivo = "S"
            Exit Select
         Case Else
            pActivo = "X" 'como ninguno es X,m devuelve todos los temas
            Exit Select
      End Select

      Dim par_Estado As SqlParameter = New SqlParameter("@pExcluye", SqlDbType.VarChar)
      par_Estado.Value = pActivo
      SQLCmd.Parameters.Add(par_Estado)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function Mantenimiento_Usuarios(ByVal pActivo As String) As Data.DataSet

      Call Prepara_Comando("Mant_Usuarios")

      'El store procedure funciona por exclusión, asi que aquí
      'se hace necesaria la conversion del parámetro

      pActivo = pActivo.ToUpper
      Select Case pActivo
         Case "S"
            pActivo = "N"
            Exit Select
         Case "N"
            pActivo = "S"
            Exit Select
         Case Else
            pActivo = "X" 'como ninguno es X, devuelve todos los usuarios
            Exit Select
      End Select

      Dim par_Estado As SqlParameter = New SqlParameter("@pExcluye", SqlDbType.VarChar)
      par_Estado.Value = pActivo
      SQLCmd.Parameters.Add(par_Estado)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
  Public Function Mantenimiento_Destinatarios(ByVal pActivo As String) As Data.DataSet

      Call Prepara_Comando("Mant_Destinatarios")

      'El store procedure funciona por exclusión, asi que aquí
      'se hace necesaria la conversion del parámetro

      pActivo = pActivo.ToUpper
      Select Case pActivo
         Case "S"
            pActivo = "N"
            Exit Select
         Case "N"
            pActivo = "S"
            Exit Select
         Case Else
            pActivo = "X" 'como ninguno es X, devuelve todos los destinatarios
            Exit Select
      End Select

      Dim par_Estado As SqlParameter = New SqlParameter("@pExcluye", SqlDbType.VarChar)
      par_Estado.Value = pActivo
      SQLCmd.Parameters.Add(par_Estado)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
 Public Function Mantenimiento_Instituciones(ByVal pActivo As String) As Data.DataSet

      Call Prepara_Comando("Mant_Instituciones")

      'El store procedure funciona por exclusión, asi que aquí
      'se hace necesaria la conversion del parámetro

      pActivo = pActivo.ToUpper
      Select Case pActivo
         Case "S"
            pActivo = "N"
            Exit Select
         Case "N"
            pActivo = "S"
            Exit Select
         Case Else
            pActivo = "X" 'como ninguno es X, devuelve todas las instituciones
            Exit Select
      End Select

      Dim par_Estado As SqlParameter = New SqlParameter("@pExcluye", SqlDbType.VarChar)
      par_Estado.Value = pActivo
      SQLCmd.Parameters.Add(par_Estado)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function ObtieneFirmador(ByVal pTConse As String) As Data.DataSet
      Dim sNivel As String

      sNivel = ""
      Select Case pTConse
         Case "ACU"
            sNivel = "1___"
            Exit Select
         Case "DIC"
            sNivel = "_1__"
            Exit Select
         Case "OFI"
            sNivel = "__1_"
            Exit Select
         Case "RES"
            sNivel = "___1"
            Exit Select
      End Select

      Call Prepara_Comando("Get_Firmadores")

      Dim par_Estado As SqlParameter = New SqlParameter("@pNivel", SqlDbType.VarChar)
      par_Estado.Value = sNivel
      SQLCmd.Parameters.Add(par_Estado)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function Get_Usuario(ByVal pCodUsu As String) As DataSet

      Call Prepara_Comando("Get_Usuario")

      Dim par_Usu As SqlParameter = New SqlParameter("@pCodUsu", SqlDbType.VarChar)
      par_Usu.Value = pCodUsu
      SQLCmd.Parameters.Add(par_Usu)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function Get_Destinatario(ByVal pCodDest As String) As DataSet

      Call Prepara_Comando("Get_Destinatario")

      Dim par_Dest As SqlParameter = New SqlParameter("@pCodDest", SqlDbType.VarChar)
      par_Dest.Value = pCodDest
      SQLCmd.Parameters.Add(par_Dest)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function Get_Institucion(ByVal pCodInst As String) As DataSet

      Call Prepara_Comando("Get_Institucion")

      Dim par_Inst As SqlParameter = New SqlParameter("@pCodInst", SqlDbType.VarChar)
      par_Inst.Value = pCodInst
      SQLCmd.Parameters.Add(par_Inst)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function Get_Tema(ByVal pCodInst As String) As DataSet

      Call Prepara_Comando("Get_Tema")

      Dim par_Cod As SqlParameter = New SqlParameter("@pCodigo", SqlDbType.VarChar)
      par_Cod.Value = pCodInst
      SQLCmd.Parameters.Add(par_Cod)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function ObtieneConsecutivo(ByVal pTConse As String, ByVal pConse As String) As DataSet

      Call Prepara_Comando("Get_Consecutivo")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      Dim par_Year As SqlParameter = New SqlParameter("@pAño", SqlDbType.VarChar)
      par_Year.Value = pConse.Substring(0, 4)
      SQLCmd.Parameters.Add(par_Year)

      Dim par_Num As SqlParameter = New SqlParameter("@pNum", SqlDbType.VarChar)
      par_Num.Value = pConse.Substring(5)
      SQLCmd.Parameters.Add(par_Num)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function ObtieneHistorico(ByVal pTConse As String, ByVal pConse As String) As DataSet

      Call Prepara_Comando("Get_Historico")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      Dim par_Year As SqlParameter = New SqlParameter("@pAño", SqlDbType.VarChar)
      par_Year.Value = pConse.Substring(0, 4)
      SQLCmd.Parameters.Add(par_Year)

      Dim par_Num As SqlParameter = New SqlParameter("@pNum", SqlDbType.VarChar)
      par_Num.Value = pConse.Substring(5)
      SQLCmd.Parameters.Add(par_Num)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Archivos(ByVal pTConse As String, ByVal pConse As String) As DataSet

      Call Prepara_Comando("Get_Archivos")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      Dim par_Year As SqlParameter = New SqlParameter("@pAño", SqlDbType.VarChar)
      par_Year.Value = pConse.Substring(0, 4)
      SQLCmd.Parameters.Add(par_Year)

      Dim par_Num As SqlParameter = New SqlParameter("@pNum", SqlDbType.VarChar)
      par_Num.Value = pConse.Substring(5)
      SQLCmd.Parameters.Add(par_Num)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
   Public Sub Agregar_Archivo(ByVal pTConse As String, ByVal pConse As String, ByVal FName As String)

      Call Prepara_Comando("Inserta_Archivo")

      Dim par_Conse As SqlParameter = New SqlParameter("@pTipo", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      Dim par_Year As SqlParameter = New SqlParameter("@pAño", SqlDbType.VarChar)
      par_Year.Value = pConse.Substring(0, 4)
      SQLCmd.Parameters.Add(par_Year)

      Dim par_Num As SqlParameter = New SqlParameter("@pNum", SqlDbType.VarChar)
      par_Num.Value = pConse.Substring(5)
      SQLCmd.Parameters.Add(par_Num)

      Dim par_Arch As SqlParameter = New SqlParameter("@pArchName", SqlDbType.VarChar)
      par_Arch.Value = FName
      SQLCmd.Parameters.Add(par_Arch)

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Eliminar_Archivo(ByVal pTConse As String, ByVal pConse As String, ByVal FName As String)

      Call Prepara_Comando("Elimina_Archivo")

      Dim par_Conse As SqlParameter = New SqlParameter("@pTipo", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      Dim par_Year As SqlParameter = New SqlParameter("@pAño", SqlDbType.VarChar)
      par_Year.Value = pConse.Substring(0, 4)
      SQLCmd.Parameters.Add(par_Year)

      Dim par_Num As SqlParameter = New SqlParameter("@pNum", SqlDbType.VarChar)
      par_Num.Value = pConse.Substring(5)
      SQLCmd.Parameters.Add(par_Num)

      Dim par_Arch As SqlParameter = New SqlParameter("@pArchName", SqlDbType.VarChar)
      par_Arch.Value = FName
      SQLCmd.Parameters.Add(par_Arch)

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Elimina_Consecutivo(ByVal pTConse As String, ByVal pConse As String)

      Call Prepara_Comando("Elimina_Consecutivo")

      Dim par_Conse As SqlParameter = New SqlParameter("@pTipo", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      Dim par_Year As SqlParameter = New SqlParameter("@pAño", SqlDbType.VarChar)
      par_Year.Value = pConse.Substring(0, 4)
      SQLCmd.Parameters.Add(par_Year)

      Dim par_Num As SqlParameter = New SqlParameter("@pNum", SqlDbType.VarChar)
      par_Num.Value = pConse.Substring(5)
      SQLCmd.Parameters.Add(par_Num)

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Elimina_Usuario(ByVal pUsuario As String)

      Call Prepara_Comando("Elimina_Usuario")

      Dim par_Usu As SqlParameter = New SqlParameter("@pCodigo", SqlDbType.VarChar)
      par_Usu.Value = pUsuario
      SQLCmd.Parameters.Add(par_Usu)

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Elimina_Destinatario(ByVal pCodDest As String)

      Call Prepara_Comando("Elimina_Destinatario")

      Dim par_Dest As SqlParameter = New SqlParameter("@pCodigo", SqlDbType.VarChar)
      par_Dest.Value = pCodDest
      SQLCmd.Parameters.Add(par_Dest)

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Elimina_Institucion(ByVal pCodInst As String)

      Call Prepara_Comando("Elimina_Institucion")

      Dim par_Inst As SqlParameter = New SqlParameter("@pCodigo", SqlDbType.VarChar)
      par_Inst.Value = pCodInst
      SQLCmd.Parameters.Add(par_Inst)

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Elimina_Tema(ByVal pCodigo As String)

      Call Prepara_Comando("Elimina_Tema")

      Dim par_Cod As SqlParameter = New SqlParameter("@pCodigo", SqlDbType.VarChar)
      par_Cod.Value = pCodigo
      SQLCmd.Parameters.Add(par_Cod)

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Function Transfiere_Consecutivos(ByVal pTConse As String, ByVal pYear As String) As Integer
      Dim Status As Integer

      Call Prepara_Comando("Tfr_Consecutivos")

      Dim par_Conse As SqlParameter = New SqlParameter("@pTipo", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      Dim par_Year As SqlParameter = New SqlParameter("@pYear", SqlDbType.VarChar)
      par_Year.Value = pYear
      SQLCmd.Parameters.Add(par_Year)

      Try
         SQLCmd.ExecuteNonQuery()
         Status = 0
      Catch ex As Exception
         Status = 1
      End Try

      Call Cierra_Conexion()

      If Status = 0 Then
         'si no hubo error en la transferencia, procede a borrar los datos
         Call Prepara_Comando("Tfr_Consecutivos_Borrado")
         SQLCmd.Parameters.Add(par_Conse)
         SQLCmd.Parameters.Add(par_Year)
         Try
            SQLCmd.ExecuteNonQuery()
            Status = 0
         Catch ex As Exception
            Status = 2
         End Try
         Call Cierra_Conexion()
      End If
      Return Status

   End Function
   <WebMethod()> _
   Public Sub Graba_Consecutivos(ByVal pAct As String, ByVal pParams As List(Of DatosParam))
      Dim p As DatosParam

      If pAct = "ADD" Then
         Call Prepara_Comando("Inserta_Consecutivo")
      Else ' accion = CHG
         Call Prepara_Comando("Modifica_Consecutivo")
      End If

      For Each p In pParams
         Select Case p.Nombre
            Case "TConse"
               Dim par_Conse As SqlParameter = New SqlParameter("@pTipo", SqlDbType.VarChar)
               par_Conse.Value = p.valor
               SQLCmd.Parameters.Add(par_Conse)
               Exit Select
            Case "Año"
               Dim par_Year As SqlParameter = New SqlParameter("@pAño", SqlDbType.VarChar)
               par_Year.Value = p.valor
               SQLCmd.Parameters.Add(par_Year)
               Exit Select
            Case "Numero"
               If pAct = "CHG" Then
                  Dim par_Num As SqlParameter = New SqlParameter("@pNum", SqlDbType.VarChar)
                  par_Num.Value = p.valor
                  SQLCmd.Parameters.Add(par_Num)
               End If
               Exit Select
            Case "Fecha"
               If pAct = "ADD" Then
                  Dim par_Fecha As SqlParameter = New SqlParameter("@pFecha", SqlDbType.VarChar)
                  par_Fecha.Value = Format(Convert.ToDateTime(p.valor), "yyyy/MM/dd HH:mm:ss")
                  SQLCmd.Parameters.Add(par_Fecha)
               End If
               Exit Select
            Case "Insti"
               Dim par_Inst As SqlParameter = New SqlParameter("@pInst", SqlDbType.VarChar)
               par_Inst.Value = p.valor
               SQLCmd.Parameters.Add(par_Inst)
               Exit Select
            Case "Dest"
               Dim par_Dest As SqlParameter = New SqlParameter("@pDest", SqlDbType.VarChar)
               par_Dest.Value = p.valor
               SQLCmd.Parameters.Add(par_Dest)
               Exit Select
            Case "Asunto"
               Dim par_Asu As SqlParameter = New SqlParameter("@pAsunto", SqlDbType.VarChar)
               par_Asu.Value = p.valor
               SQLCmd.Parameters.Add(par_Asu)
               Exit Select
            Case "Tema"
               Dim par_Tema As SqlParameter = New SqlParameter("@pTema", SqlDbType.VarChar)
               par_Tema.Value = p.valor
               SQLCmd.Parameters.Add(par_Tema)
               Exit Select
            Case "Trámite"
               If pAct = "ADD" Then
                  Dim par_Tram As SqlParameter = New SqlParameter("@pTramite", SqlDbType.VarChar)
                  par_Tram.Value = p.valor
                  SQLCmd.Parameters.Add(par_Tram)
               End If
               Exit Select
            Case "Confi"
               Dim par_Confi As SqlParameter = New SqlParameter("@pConfi", SqlDbType.VarChar)
               par_Confi.Value = p.Valor
               SQLCmd.Parameters.Add(par_Confi)
               Exit Select
            Case "Firma"
               Dim par_Firma As SqlParameter = New SqlParameter("@pCodFirma", SqlDbType.VarChar)
               par_Firma.Value = p.Valor
               SQLCmd.Parameters.Add(par_Firma)
               Exit Select
            Case "Elab"
               If pAct = "ADD" Then
                  Dim par_Elab As SqlParameter = New SqlParameter("@pCodElab", SqlDbType.VarChar)
                  par_Elab.Value = p.Valor
                  SQLCmd.Parameters.Add(par_Elab)
               End If
               Exit Select
         End Select
      Next

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Graba_Usuarios(ByVal pAct As String, ByVal pParams As List(Of DatosParam))
      Dim p As DatosParam

      If pAct = "ADD" Then
         Call Prepara_Comando("Inserta_Usuario")
      Else ' accion = CHG
         Call Prepara_Comando("Modifica_Usuario")
      End If

      For Each p In pParams
         Select Case p.Nombre
            Case "Codigo"
               Dim par_Codigo As SqlParameter = New SqlParameter("@pCodigo", SqlDbType.VarChar)
               par_Codigo.Value = p.Valor
               SQLCmd.Parameters.Add(par_Codigo)
               Exit Select
            Case "Nombre"
               Dim par_Nombre As SqlParameter = New SqlParameter("@pNombre", SqlDbType.VarChar)
               par_Nombre.Value = p.Valor
               SQLCmd.Parameters.Add(par_Nombre)
               Exit Select
            Case "Nivel"
               Dim par_Nivel As SqlParameter = New SqlParameter("@pNivel", SqlDbType.VarChar)
               par_Nivel.Value = p.Valor
               SQLCmd.Parameters.Add(par_Nivel)
               Exit Select
            Case "Activo"
               Dim par_Activo As SqlParameter = New SqlParameter("@pActivo", SqlDbType.VarChar)
               par_Activo.Value = p.Valor
               SQLCmd.Parameters.Add(par_Activo)
               Exit Select
         End Select
      Next

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Graba_Destinatario(ByVal pAct As String, ByVal pParams As List(Of DatosParam))
      Dim p As DatosParam

      If pAct = "ADD" Then
         Call Prepara_Comando("Inserta_Destinatario")
      Else ' accion = CHG
         Call Prepara_Comando("Modifica_Destinatario")
      End If

      For Each p In pParams
         Select Case p.Nombre
            Case "Codigo"
               If pAct = "CHG" Then
                  Dim par_Codigo As SqlParameter = New SqlParameter("@pCodigo", SqlDbType.VarChar)
                  par_Codigo.Value = p.Valor
                  SQLCmd.Parameters.Add(par_Codigo)
               End If
               Exit Select
            Case "Nombre"
               Dim par_Nombre As SqlParameter = New SqlParameter("@pNombre", SqlDbType.VarChar)
               par_Nombre.Value = p.Valor
               SQLCmd.Parameters.Add(par_Nombre)
               Exit Select
            Case "Inst"
               Dim par_Inst As SqlParameter = New SqlParameter("@pCodInst", SqlDbType.VarChar)
               par_Inst.Value = p.Valor
               SQLCmd.Parameters.Add(par_Inst)
               Exit Select
            Case "Activo"
               Dim par_Activo As SqlParameter = New SqlParameter("@pActivo", SqlDbType.VarChar)
               par_Activo.Value = p.Valor
               SQLCmd.Parameters.Add(par_Activo)
               Exit Select
         End Select
      Next

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Graba_Institucion(ByVal pAct As String, ByVal pParams As List(Of DatosParam))
      Dim p As DatosParam

      If pAct = "ADD" Then
         Call Prepara_Comando("Inserta_Institucion")
      Else ' accion = CHG
         Call Prepara_Comando("Modifica_Institucion")
      End If

      For Each p In pParams
         Select Case p.Nombre
            Case "Codigo"
               If pAct = "CHG" Then
                  Dim par_Codigo As SqlParameter = New SqlParameter("@pCodigo", SqlDbType.VarChar)
                  par_Codigo.Value = p.Valor
                  SQLCmd.Parameters.Add(par_Codigo)
               End If
               Exit Select
            Case "Nombre"
               Dim par_Nombre As SqlParameter = New SqlParameter("@pNombre", SqlDbType.VarChar)
               par_Nombre.Value = p.Valor
               SQLCmd.Parameters.Add(par_Nombre)
               Exit Select
            Case "Activo"
               Dim par_Activo As SqlParameter = New SqlParameter("@pActivo", SqlDbType.VarChar)
               par_Activo.Value = p.Valor
               SQLCmd.Parameters.Add(par_Activo)
               Exit Select
         End Select
      Next

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Graba_Tema(ByVal pAct As String, ByVal pParams As List(Of DatosParam))
      Dim p As DatosParam

      If pAct = "ADD" Then
         Call Prepara_Comando("Inserta_Tema")
      Else ' accion = CHG
         Call Prepara_Comando("Modifica_Tema")
      End If

      For Each p In pParams
         Select Case p.Nombre
            Case "Codigo"
               If pAct = "CHG" Then
                  Dim par_Codigo As SqlParameter = New SqlParameter("@pCodigo", SqlDbType.VarChar)
                  par_Codigo.Value = p.Valor
                  SQLCmd.Parameters.Add(par_Codigo)
               End If
               Exit Select
            Case "Descrip"
               Dim par_Descrip As SqlParameter = New SqlParameter("@pDescrip", SqlDbType.VarChar)
               par_Descrip.Value = p.Valor
               SQLCmd.Parameters.Add(par_Descrip)
               Exit Select
            Case "Activo"
               Dim par_Activo As SqlParameter = New SqlParameter("@pActivo", SqlDbType.VarChar)
               par_Activo.Value = p.Valor
               SQLCmd.Parameters.Add(par_Activo)
               Exit Select
         End Select
      Next

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Graba_Parametros(ByVal pParams As List(Of DatosParam))
      Dim p As DatosParam

      Call Prepara_Comando("Inserta_Params")

      For Each p In pParams
         Select Case p.Nombre
            Case "DirAnexos"
               Dim par_DirAn As SqlParameter = New SqlParameter("@pDirAnexos", SqlDbType.VarChar)
               par_DirAn.Value = p.Valor
               SQLCmd.Parameters.Add(par_DirAn)
               Exit Select
         End Select
      Next

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
   Public Sub Graba_Fecha_Import(ByVal pParams As List(Of DatosParam))
      Dim p As DatosParam

      Call Prepara_Comando("Modifica_Fecha_Import_Inst")

      For Each p In pParams
         Select Case p.Nombre
            Case "Fecha"
               Dim par_Fecha As SqlParameter = New SqlParameter("@pFecha", SqlDbType.VarChar)
               par_Fecha.Value = p.Valor
               SQLCmd.Parameters.Add(par_Fecha)
               Exit Select
         End Select
      Next

      SQLCmd.ExecuteNonQuery()

      Call Cierra_Conexion()

   End Sub
   <WebMethod()> _
    Public Function ObtieneConsecutivos(ByVal pTConse As String, ByVal pFiltro As String) As DataSet
      Dim AuxWhere As String, Split As String(), Param As String, AuxBusca As String
      Dim Token As String, sData As String, sRslt As String
      Dim sDesde As String, sHasta As String, sAño As String, sMes As String
      Dim iComb As Integer

      AuxBusca = ""
      AuxWhere = "a.Tipo_Consec = '" & pTConse & "'"
      iComb = 0
      sMes = ""
      sAño = ""
      sDesde = ""
      sHasta = ""

      If pFiltro IsNot Nothing And pFiltro.Trim.Length > 10 Then
         If pFiltro.EndsWith(MkChr) Then
            pFiltro = pFiltro.Substring(0, pFiltro.Length - 1)
         End If
         Split = pFiltro.Split(MkChr)
         For Each Param In Split
            Token = Param.Substring(0, 6)
            sData = Param.Substring(6)
            Select Case Token
               Case "BComb_"
                  'implica combinar ambas opciones de busqueda de consecutivos
                  'la estandar y la avanzada
                  iComb = CInt(sData)
               Case "BCons_"
                  'estos tokens implican el resultado de la búsqueda de un texto
                  'en los archivos del consecutivo
                  AuxBusca = AuxBusca & " or (a.Año ='" & sData.Substring(0, 4) & _
                     "' and a.Num_Consec=" & sData.Substring(4) & ")"
               Case "BMesS_"
                  'viene el numero de mes
                  sMes = sData
               Case "BAñoS_"
                  'viene el año en yyyy
                  sAño = sData
               Case "BDesd_"
                  'viene una fecha en dd/mm/yyyy
                  sDesde = sData
               Case "BHast_"
                  'viene una fecha en dd/mm/yyyy
                  sHasta = sData
               Case "Conse_"
                  AuxWhere = AuxWhere & " and a.Año='" & sData.Substring(0, 4) & _
                     "' and a.Num_Consec=" & sData.Substring(4)
               Case "Insti_"
                  AuxWhere = AuxWhere & " and a.Cod_Institucion ='" & sData & "'"
               Case "Fecha_"
                  AuxWhere = AuxWhere & " and convert(nvarchar,a.Fecha,112) ='" & _
                     sData & "'"
               Case "Desti_"
                  AuxWhere = AuxWhere & " and a.Cod_Destinatario ='" & sData & "'"
               Case "Asunt_"
                  AuxWhere = AuxWhere & " and a.Asunto like '%" & sData & "%'"
               Case "Categ_"
                  AuxWhere = AuxWhere & " and a.Cod_Categoria ='" & sData & "'"
               Case "Temas_"
                  AuxWhere = AuxWhere & " and a.Cod_Tema ='" & sData & "'"
               Case "Firma_"
                  AuxWhere = AuxWhere & " and a.Cod_Usu_Firmador ='" & sData & "'"
            End Select
         Next Param
      End If

      Select Case iComb
         Case 0 'solo utiliza opciones basicas
            AuxWhere = " WHERE (" & AuxWhere & ")"
         Case 1 'solo utiliza opciones avanzadas
            'evita las opciones básicas
            AuxWhere = "a.Tipo_Consec = '" & pTConse & "'"

            sRslt = Analiza_Rangos_Fechas(sAño, sMes, sDesde, sHasta)
            If sRslt.Length > 0 Then
               AuxWhere = AuxWhere & sRslt
            End If
            If AuxBusca.Length > 0 Then
               AuxWhere = " WHERE (" & AuxWhere & " and (" & AuxBusca.Substring(3) & "))"
            Else
               AuxWhere = " WHERE (" & AuxWhere & ")"
            End If
         Case 2 'utiliza ambas opciones
            sRslt = Analiza_Rangos_Fechas(sAño, sMes, sDesde, sHasta)
            If sRslt.Length > 0 Then
               AuxWhere = AuxWhere & sRslt
            End If
            If AuxBusca.Length > 0 Then
               AuxWhere = " WHERE (" & AuxWhere & " and (" & AuxBusca.Substring(3) & "))"
            Else
               AuxWhere = " WHERE (" & AuxWhere & ")"
            End If
      End Select

      Call Prepara_Comando("Get_Consecutivos")

      Dim par_Where As SqlParameter = New SqlParameter("@pWhere", SqlDbType.VarChar)
      par_Where.Value = AuxWhere
      SQLCmd.Parameters.Add(par_Where)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      'prueba
      'Dim dtr As Data.DataTableReader
      'dtr = DS.CreateDataReader
      'dtr.Read()
      'Dim s As String
      's = dtr.GetString(0)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   <WebMethod()> _
    Public Function ObtieneHistoricos(ByVal pTConse As String, ByVal pFiltro As String) As DataSet
      Dim AuxWhere As String, Split As String(), Param As String, AuxBusca As String
      Dim Token As String, sData As String, sRslt As String
      Dim sDesde As String, sHasta As String, sAño As String, sMes As String
      Dim iComb As Integer

      AuxBusca = ""
      AuxWhere = "a.Tipo_Consec = '" & pTConse & "'"
      iComb = 0
      sMes = ""
      sAño = ""
      sDesde = ""
      sHasta = ""

      If pFiltro IsNot Nothing And pFiltro.Trim.Length > 10 Then
         If pFiltro.EndsWith(MkChr) Then
            pFiltro = pFiltro.Substring(0, pFiltro.Length - 1)
         End If
         Split = pFiltro.Split(MkChr)
         For Each Param In Split
            Token = Param.Substring(0, 6)
            sData = Param.Substring(6)
            Select Case Token
               Case "BComb_"
                  'implica combinar ambas opciones de busqueda de consecutivos
                  'la estandar y la avanzada
                  iComb = CInt(sData)
               Case "BCons_"
                  'estos tokens implican el resultado de la búsqueda de un texto
                  'en los archivos del consecutivo
                  AuxBusca = AuxBusca & " or (a.Año ='" & sData.Substring(0, 4) & _
                     "' and a.Num_Consec=" & sData.Substring(4) & ")"
               Case "BMesS_"
                  'viene el numero de mes
                  sMes = sData
               Case "BAñoS_"
                  'viene el año en yyyy
                  sAño = sData
               Case "BDesd_"
                  'viene una fecha en dd/mm/yyyy
                  sDesde = sData
               Case "BHast_"
                  'viene una fecha en dd/mm/yyyy
                  sHasta = sData
               Case "Conse_"
                  AuxWhere = AuxWhere & " and a.Año='" & sData.Substring(0, 4) & _
                     "' and a.Num_Consec=" & sData.Substring(4)
               Case "Insti_"
                  AuxWhere = AuxWhere & " and a.Institucion ='" & sData & "'"
               Case "Fecha_"
                  AuxWhere = AuxWhere & " and convert(nvarchar,a.Fecha,112) ='" & _
                     sData & "'"
               Case "Desti_"
                  AuxWhere = AuxWhere & " and a.Destinatario ='" & sData & "'"
               Case "Asunt_"
                  AuxWhere = AuxWhere & " and a.Asunto like '%" & sData & "%'"
               Case "Temas_"
                  AuxWhere = AuxWhere & " and a.Tema ='" & sData & "'"
               Case "Firma_"
                  AuxWhere = AuxWhere & " and a.Usu_Firmador ='" & sData & "'"
            End Select
         Next Param
      End If

      Select Case iComb
         Case 0 'solo utiliza opciones basicas
            AuxWhere = " WHERE (" & AuxWhere & ")"
         Case 1 'solo utiliza opciones avanzadas
            'evita las opciones básicas
            AuxWhere = "a.Tipo_Consec = '" & pTConse & "'"

            sRslt = Analiza_Rangos_Fechas(sAño, sMes, sDesde, sHasta)
            If sRslt.Length > 0 Then
               AuxWhere = AuxWhere & sRslt
            End If
            If AuxBusca.Length > 0 Then
               AuxWhere = " WHERE (" & AuxWhere & " and (" & AuxBusca.Substring(3) & "))"
            Else
               AuxWhere = " WHERE (" & AuxWhere & ")"
            End If
         Case 2 'utiliza ambas opciones
            sRslt = Analiza_Rangos_Fechas(sAño, sMes, sDesde, sHasta)
            If sRslt.Length > 0 Then
               AuxWhere = AuxWhere & sRslt
            End If
            If AuxBusca.Length > 0 Then
               AuxWhere = " WHERE (" & AuxWhere & " and (" & AuxBusca.Substring(3) & "))"
            Else
               AuxWhere = " WHERE (" & AuxWhere & ")"
            End If
      End Select

      Call Prepara_Comando("Get_Historicos")

      Dim par_Where As SqlParameter = New SqlParameter("@pWhere", SqlDbType.VarChar)
      par_Where.Value = AuxWhere
      SQLCmd.Parameters.Add(par_Where)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   Private Function Analiza_Rangos_Fechas(ByVal pAño As String, ByVal pMes As String, ByVal pDesde As String, ByVal pHasta As String) As String
      Dim Split As String(), sRslt As String

      sRslt = ""
      If pDesde.Length = 0 Then
         'si no hay Desde y Hasta, analiza los otros parámetros de tiempo
         If pMes.Length = 0 Then
            If pAño.Length > 0 Then
               pDesde = pAño & "0100"
               pHasta = pAño & "1232"
            Else
               'todos los campos de tiempo están vacíos
            End If
         Else
            If pAño.Length = 0 Then
               pAño = CStr(Now.Year)
            End If
            pDesde = pAño & Format(CInt(pMes), "00") & "00"
            pHasta = pAño & Format(CInt(pMes), "00") & "32"
         End If
      Else
         'transforma el desde y hasta de dd/mm/yyyy a yyyymmdd
         Split = pDesde.Split("/")
         pDesde = Split(2) & Split(1) & Format(CInt(Split(0)) - 1, "00")
         Split = pHasta.Split("/")
         pHasta = Split(2) & Split(1) & Format(CInt(Split(0)) + 1, "00")
      End If
      If pDesde.Length > 0 Then
         sRslt = " and convert(nvarchar,a.Fecha,112) > '" & _
            pDesde & "' and convert(nvarchar,a.Fecha,112) < '" & pHasta & "'"
      End If
      Return sRslt
   End Function
   <WebMethod()> _
    Public Function Obtiene_NumConsec_EnUso(ByVal pTConse As String) As DataSet

      Call Prepara_Comando("Get_Numeros_Consec")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Consec"))
      Dim StrAux As String
      dataset.Tables(0).Rows.Add(Space(3))

      While DTR.Read()
         StrAux = DTR.GetString(DTR.GetOrdinal("Año")) & "-" & _
                  Format(DTR.GetValue(DTR.GetOrdinal("Num_Consec")), "00000")
         dataset.Tables(0).Rows.Add(StrAux)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
       Public Function Obtiene_NumConsec_Histo(ByVal pTConse As String) As DataSet

      Call Prepara_Comando("Get_Numeros_Consec_Histo")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Consec"))
      Dim StrAux As String
      dataset.Tables(0).Rows.Add(Space(3))

      While DTR.Read()
         StrAux = DTR.GetString(DTR.GetOrdinal("Año")) & "-" & _
                  Format(DTR.GetValue(DTR.GetOrdinal("Num_Consec")), "00000")
         dataset.Tables(0).Rows.Add(StrAux)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Fechas_EnUso(ByVal pTConse As String) As DataSet

      Call Prepara_Comando("Get_Distinct_Fechas")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Fecha"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("FechaYMD"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      workRow("Fecha") = Space(3)
      workRow("FechaYMD") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)

      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         workRow("Fecha") = CStr(DTR.GetValue(DTR.GetOrdinal("Dia"))) & "/" & _
            CStr(DTR.GetValue(DTR.GetOrdinal("Mes"))) & "/" & _
            CStr(DTR.GetValue(DTR.GetOrdinal("Año")))
         workRow("FechaYMD") = CStr(DTR.GetValue(DTR.GetOrdinal("Año"))) & _
            CStr(DTR.GetValue(DTR.GetOrdinal("Mes"))) & _
            CStr(DTR.GetValue(DTR.GetOrdinal("Dia")))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Fechas_Histo(ByVal pTConse As String) As DataSet

      Call Prepara_Comando("Get_Distinct_Fechas_Histo")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Fecha"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("FechaYMD"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      workRow("Fecha") = Space(3)
      workRow("FechaYMD") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)

      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         workRow("Fecha") = CStr(DTR.GetValue(DTR.GetOrdinal("Dia"))) & "/" & _
            CStr(DTR.GetValue(DTR.GetOrdinal("Mes"))) & "/" & _
            CStr(DTR.GetValue(DTR.GetOrdinal("Año")))
         workRow("FechaYMD") = CStr(DTR.GetValue(DTR.GetOrdinal("Año"))) & _
            CStr(DTR.GetValue(DTR.GetOrdinal("Mes"))) & _
            CStr(DTR.GetValue(DTR.GetOrdinal("Dia")))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Instituciones_EnUso(ByVal pTConse As String) As DataSet

      Call Prepara_Comando("Get_Distinct_Insti")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Cod_Insti"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Nom_Insti"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()

      workRow("Cod_Insti") = Space(3)
      workRow("Nom_Insti") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)

      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         workRow("Cod_Insti") = DTR.GetValue(DTR.GetOrdinal("Cod_Institucion"))
         workRow("Nom_Insti") = DTR.GetValue(DTR.GetOrdinal("Nom_Inst"))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Instituciones_Histo(ByVal pTConse As String) As DataSet

      Call Prepara_Comando("Get_Distinct_Insti_Histo")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      'dataset.Tables(0).Columns.Add(New Data.DataColumn("Cod_Insti"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Nom_Insti"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()

      'workRow("Cod_Insti") = Space(3)
      workRow("Nom_Insti") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)

      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         'workRow("Cod_Insti") = DTR.GetValue(DTR.GetOrdinal("Cod_Institucion"))
         workRow("Nom_Insti") = DTR.GetValue(DTR.GetOrdinal("Institucion"))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Destinatarios_EnUso(ByVal pTConse As String) As DataSet

      Call Prepara_Comando("Get_Distinct_Dest")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Cod_Dest"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Nom_Dest"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      workRow("Cod_Dest") = Space(3)
      workRow("Nom_Dest") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)
      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         workRow("Cod_Dest") = DTR.GetValue(DTR.GetOrdinal("Cod_Destinatario"))
         workRow("Nom_Dest") = DTR.GetValue(DTR.GetOrdinal("Nom_Destinatario"))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Destinatarios_Histo(ByVal pTConse As String) As DataSet

      Call Prepara_Comando("Get_Distinct_Dest_Histo")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      'dataset.Tables(0).Columns.Add(New Data.DataColumn("Cod_Dest"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Nom_Dest"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      'workRow("Cod_Dest") = Space(3)
      workRow("Nom_Dest") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)
      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         'workRow("Cod_Dest") = DTR.GetValue(DTR.GetOrdinal("Cod_Destinatario"))
         workRow("Nom_Dest") = DTR.GetValue(DTR.GetOrdinal("Destinatario"))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Temas_EnUso(ByVal pTConse As String) As Data.DataSet

      Call Prepara_Comando("Get_Distinct_Temas")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Cod_Tema"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Desc_Tema"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      workRow("Cod_Tema") = Space(3)
      workRow("Desc_Tema") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)
      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         workRow("Cod_Tema") = DTR.GetValue(DTR.GetOrdinal("Cod_Tema"))
         workRow("Desc_Tema") = DTR.GetValue(DTR.GetOrdinal("Desc_Tema"))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Temas_Histo(ByVal pTConse As String) As Data.DataSet

      Call Prepara_Comando("Get_Distinct_Temas_Histo")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      'dataset.Tables(0).Columns.Add(New Data.DataColumn("Cod_Tema"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Desc_Tema"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      'workRow("Cod_Tema") = Space(3)
      workRow("Desc_Tema") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)
      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         'workRow("Cod_Tema") = DTR.GetValue(DTR.GetOrdinal("Cod_Tema"))
         workRow("Desc_Tema") = DTR.GetValue(DTR.GetOrdinal("Tema"))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Firmador_EnUso(ByVal pTConse As String) As Data.DataSet

      Call Prepara_Comando("Get_Distinct_Firmador")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader
      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Cod_Usu"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Nom_Usu"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      workRow("Cod_Usu") = Space(3)
      workRow("Nom_Usu") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)
      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         workRow("Cod_Usu") = DTR.GetValue(DTR.GetOrdinal("Cod_Usuario"))
         workRow("Nom_Usu") = DTR.GetValue(DTR.GetOrdinal("Nom_Usuario"))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Public Function Obtiene_Firmador_Histo(ByVal pTConse As String) As Data.DataSet

      Call Prepara_Comando("Get_Distinct_Firmador_Histo")

      Dim par_Conse As SqlParameter = New SqlParameter("@TConse", SqlDbType.VarChar)
      par_Conse.Value = pTConse
      SQLCmd.Parameters.Add(par_Conse)

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Dim DTR As DataTableReader
      DTR = DS.CreateDataReader
      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      'dataset.Tables(0).Columns.Add(New Data.DataColumn("Cod_Usu"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Nom_Usu"))

      Dim workRow As Data.DataRow = dataset.Tables(0).NewRow()
      'workRow("Cod_Usu") = Space(3)
      workRow("Nom_Usu") = Space(3)
      dataset.Tables(0).Rows.Add(workRow)
      While DTR.Read()
         workRow = dataset.Tables(0).NewRow()
         'workRow("Cod_Usu") = DTR.GetValue(DTR.GetOrdinal("Cod_Usuario"))
         workRow("Nom_Usu") = DTR.GetValue(DTR.GetOrdinal("Usu_Firmador"))
         dataset.Tables(0).Rows.Add(workRow)
      End While
      DTR.Close()

      Call Cierra_Conexion()

      Return (dataset)
   End Function
   <WebMethod()> _
   Function Sincroniza_Temas() As Data.DataSet
      Dim ConnO As New Odbc.OdbcConnection
      Dim cmdO As New Odbc.OdbcCommand
      Dim DRO As Odbc.OdbcDataReader
      Dim sWork As String
      Dim TemaCol As New Collection, UbicCol As New Collection

      ConnO.ConnectionString = ConfigurationManager.ConnectionStrings("CNS_TramitesConnStr").ToString
      ConnO.Open()

      'Tabla (campos,...)
      'Institución (Institucion, Siglas, Categoria, Sigl)
      'Instituciones (Institucion, Categoria, Siglas)
      'Remintentes (Institucion, Siglas, Categoria, Nombre, TipoRem)
      'Temas (Categoria, Tema)
      'Usuarios (SendTo, Dependencia, Jefe, Usuarios_TipoEnt, Marca)

      cmdO.CommandText = "Select distinct (Tema) from Temas order by Tema"
      cmdO.Connection = ConnO
      DRO = cmdO.ExecuteReader

      While DRO.Read
         If Not (IsDBNull(DRO.GetValue(0))) Then
            sWork = DRO.GetString(0).Trim
            If sWork.Length > 80 Then
               '80: largo máximo de los temas
               sWork = sWork.Substring(0, 80)
            End If

            If TemaCol.Contains(sWork) Then
               'evita temas repetidos desde LOTUS
            Else
               TemaCol.Add(sWork, sWork)
               UbicCol.Add(1, sWork)
            End If
         End If
      End While

      Dim DS As New Data.DataSet
      Dim DR As Data.DataTableReader
      DS = Mantenimiento_Temas("X")
      DR = DS.CreateDataReader

      While DR.Read
         sWork = DR.GetString(1).Trim  'Desc_Tema es el segundo item

         If TemaCol.Contains(sWork) Then
            'primero verifica si el item ya esta en la lista
            UbicCol.Remove(sWork)
            UbicCol.Add(2, sWork)
         Else
            'si no esta en la lista, solamente esta en Consecutivos
            TemaCol.Add(sWork, sWork)
            UbicCol.Add(3, sWork)
         End If
      End While

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Temas a importar"))
      'dataset.Tables(0).Columns.Add(New Data.DataColumn("Ubicación"))

      Dim workRow As Data.DataRow
      Dim sUbic As String

      For Each sWork In TemaCol
         'solo va a enviar aquellos registros que están en Trámites
         ' y NO están en consecutivos
         sUbic = UbicCol.Item(sWork).ToString
         If sUbic = 1 Then
            workRow = dataset.Tables(0).NewRow()
            workRow("Temas a importar") = sWork
            'workRow("Ubicación") = UbicCol.Item(sWork).ToString
            dataset.Tables(0).Rows.Add(workRow)
         End If
      Next

      DS.Dispose()
      cmdO.Dispose()
      ConnO.Close()
      ConnO.Dispose()

      Return (dataset)
   End Function
   <WebMethod()> _
   Function Sincroniza_Instituciones() As Data.DataSet
      Dim ConnO As New Odbc.OdbcConnection
      Dim cmdO As New Odbc.OdbcCommand
      Dim DRO As Odbc.OdbcDataReader
      Dim sWork As String
      Dim InstCol As New Collection, UbicCol As New Collection

      ConnO.ConnectionString = ConfigurationManager.ConnectionStrings("CNS_TramitesConnStr").ToString
      ConnO.Open()

      'Tabla (campos,...)
      'Institución (Institucion, Siglas, Categoria, Sigl)
      'Instituciones (Institucion, Categoria, Siglas)
      'Remintentes (Institucion, Siglas, Categoria, Nombre, TipoRem)
      'Temas (Categoria, Tema)
      'Usuarios (SendTo, Dependencia, Jefe, Usuarios_TipoEnt, Marca)

      cmdO.CommandText = "Select distinct (Institucion) from Instituciones order by Institucion"
      cmdO.Connection = ConnO
      DRO = cmdO.ExecuteReader

      While DRO.Read
         If Not (IsDBNull(DRO.GetValue(0))) Then
            sWork = DRO.GetString(0).Trim
            If sWork.Length > 120 Then '120: largo máximo de instituciones
               sWork = sWork.Substring(0, 120)
            End If
            If InstCol.Contains(sWork) Then
               'evita instituciones repetidas desde LOTUS
            Else
               InstCol.Add(sWork, sWork)
               UbicCol.Add(1, sWork)
            End If
         End If
      End While

      Dim DS As New Data.DataSet
      Dim DR As Data.DataTableReader
      DS = Mantenimiento_Instituciones("X")
      DR = DS.CreateDataReader

      While DR.Read
         sWork = DR.GetString(1).Trim  'Nom_Inst es el segundo item

         If InstCol.Contains(sWork) Then
            'primero verifica si el item ya esta en la lista
            UbicCol.Remove(sWork)
            UbicCol.Add(2, sWork)
         Else
            'si no esta en la lista, solamente esta en Consecutivos
            InstCol.Add(sWork, sWork)
            UbicCol.Add(3, sWork)
         End If
      End While

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Instituciones a importar"))
      'dataset.Tables(0).Columns.Add(New Data.DataColumn("Ubic"))

      Dim workRow As Data.DataRow
      Dim sUbic As String

      For Each sWork In InstCol
         sUbic = UbicCol.Item(sWork).ToString
         If sUbic = 1 Then
            workRow = dataset.Tables(0).NewRow()
            workRow("Instituciones a importar") = sWork
            'workRow("Ubic") = UbicCol.Item(sWork).ToString
            dataset.Tables(0).Rows.Add(workRow)
         End If
      Next

      DS.Dispose()
      cmdO.Dispose()
      ConnO.Close()
      ConnO.Dispose()

      Return (dataset)
   End Function
   <WebMethod()> _
  Function Sincroniza_Destinatarios() As Data.DataSet
      Dim ConnO As New Odbc.OdbcConnection
      Dim cmdO As New Odbc.OdbcCommand
      Dim DRO As Odbc.OdbcDataReader
      Dim sWork As String, sAux As String
      Dim Rslt() As String
      Dim DestCol As New Collection, UbicCol As New Collection

      ConnO.ConnectionString = ConfigurationManager.ConnectionStrings("CNS_TramitesConnStr").ToString
      ConnO.Open()

      'Tabla (campos,...)
      'Institución (Institucion, Siglas, Categoria, Sigl)
      'Instituciones (Institucion, Categoria, Siglas)
      'Remintentes (Institucion, Siglas, Categoria, Nombre, TipoRem)
      'Temas (Categoria, Tema)
      'Usuarios (SendTo, Dependencia, Jefe, Usuarios_TipoEnt, Marca)

      cmdO.CommandText = "Select distinct Institucion, Nombre from Remitentes order by Institucion, Nombre"
      cmdO.Connection = ConnO
      DRO = cmdO.ExecuteReader

      While DRO.Read
         If Not (IsDBNull(DRO.GetValue(0))) Then
            sWork = DRO.GetString(0).Trim
            If sWork.Length > 120 Then
               sWork = sWork.Substring(0, 120)  '120: largo máximo de instituciones
            End If
            sAux = DRO.GetString(1).Trim
            If sAux.Length > 100 Then '100: largo máximo de destinatarios
               sAux = sAux.Substring(0, 100)
            End If
            sWork = sWork & Chr(6) & sAux

            If DestCol.Contains(sWork) Then
            Else
               DestCol.Add(sWork, sWork)
               UbicCol.Add(1, sWork)
            End If
         End If
      End While

      Dim DS As New Data.DataSet
      Dim DR As Data.DataTableReader
      DS = Sync_Destinatarios()
      DR = DS.CreateDataReader

      While DR.Read
         sWork = DR.GetString(0).Trim & Chr(6) & DR.GetString(1).Trim

         If DestCol.Contains(sWork) Then
            'primero verifica si el item ya esta en la lista
            UbicCol.Remove(sWork)
            UbicCol.Add(2, sWork)
         Else
            'si no esta en la lista, solamente esta en Consecutivos
            DestCol.Add(sWork, sWork)
            UbicCol.Add(3, sWork)
         End If
      End While

      Dim dataset As New Data.DataSet
      dataset.Tables.Add(New Data.DataTable())
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Destinatario a importar"))
      dataset.Tables(0).Columns.Add(New Data.DataColumn("Institución"))
      'dataset.Tables(0).Columns.Add(New Data.DataColumn("Ubic"))

      Dim workRow As Data.DataRow
      Dim sUbic As String

      For Each sWork In DestCol
         sUbic = UbicCol.Item(sWork).ToString
         If sUbic = 1 Then
            workRow = dataset.Tables(0).NewRow()
            Rslt = sWork.Split(Chr(6))
            workRow("Destinatario a importar") = Rslt(1)
            workRow("Institución") = Rslt(0)
            'workRow("Ubic") = UbicCol.Item(sWork).ToString
            dataset.Tables(0).Rows.Add(workRow)
         End If
      Next

      DS.Dispose()
      cmdO.Dispose()
      ConnO.Close()
      ConnO.Dispose()

      Return (dataset)
   End Function
   Function Sync_Destinatarios() As DataSet

      Call Prepara_Comando("Sync_DestinatariosxInst")

      SQLAdapter = New SqlDataAdapter()
      SQLAdapter.SelectCommand = SQLCmd
      SQLAdapter.Fill(DS)

      Call Cierra_Conexion()

      Return (DS)
   End Function
   Sub Prepara_Comando(ByVal pCmd As String)
      SQLConn = New SqlConnection(StrConn)
      SQLConn.Open()

      If SQLCmd Is Nothing Then
         SQLCmd = New SqlCommand
      Else
         SQLCmd.Parameters.Clear()
      End If
      SQLCmd.Connection = SQLConn
      SQLCmd.CommandType = CommandType.StoredProcedure
      SQLCmd.CommandText = pCmd
   End Sub
   Sub Cierra_Conexion()
      SQLConn.Close()
      SQLConn.Dispose()
   End Sub
End Class
Public Class DatosParam
   Dim _Nombre As String
   Dim _Valor As String
   Public Property Nombre() As String
      Get
         Return _Nombre
      End Get
      Set(ByVal value As String)
         _Nombre = value
      End Set
   End Property
   Public Property Valor() As String
      Get
         Return _Valor
      End Get
      Set(ByVal value As String)
         _Valor = value
      End Set
   End Property
End Class
