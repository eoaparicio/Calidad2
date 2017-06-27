Imports System.Web
Imports System.Web.Services
Imports System.Web.Services.Protocols
Imports System.Data.SqlClient
Imports System.Data

<WebService(Namespace:="http://tempuri.org/")> _
<WebServiceBinding(ConformsTo:=WsiProfiles.BasicProfile1_1)> _
<Global.Microsoft.VisualBasic.CompilerServices.DesignerGenerated()> _
Public Class Ws_Seg
    Inherits System.Web.Services.WebService
    Private Shared Conn_String As String = ConfigurationManager.ConnectionStrings("Seg_ConnectionString").ToString
    'Friend v_DirArch As String = System.Configuration.ConfigurationSettings.AppSettings("Dir_Arch")
    'Objeto tipo sqlconnection para establecer la conexion con la base de datos.
    Private Shared DBConn As New SqlConnection
    'Objeto mediante el cual accesaremos los datos.
    Friend DBAdapter As New SqlDataAdapter
    'Objeto para ejecutar comandos sobre la base de datos
    Friend DBCommand As New SqlCommand
    'Objeto donde se almacenarán los resultados de las consultas que se realicen
    Friend DS As New DataSet
    Private v_Error As String 'Error
    'Atributo para crear cadenas de caracteres
    'Friend consulta As String

    <WebMethod()> _
    Public Function obteneraplicaciones(ByVal p_usuario As String, ByVal p_sistema As String) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "ObtenerAplicaciones"
        Dim p_usr As SqlParameter = New SqlParameter("@usuario", SqlDbType.VarChar)
        p_usr.Value = p_usuario
        DBCommand.Parameters.Add(p_usr)
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        If IsDBNull(p_sistema) = False And Len(p_sistema) > 0 Then
            p_sis.Value = p_sistema
            DBCommand.Parameters.Add(p_sis)
        End If
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
Public Function grid_aplicaciones(ByVal p_sistema As String) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "grid_Aplicaciones"
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        If IsDBNull(p_sistema) = False And Len(p_sistema) > 0 Then
            p_sis.Value = p_sistema
            DBCommand.Parameters.Add(p_sis)
        End If
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
   Public Function grid_apl_menu(ByVal p_sistema As String, ByVal p_opcion As Integer) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "grid_Apl_Menu"
        Dim p_sis As SqlParameter = New SqlParameter("@p_apl", SqlDbType.VarChar)
        If IsDBNull(p_sistema) = False And Len(p_sistema) > 0 Then
            p_sis.Value = p_sistema
            DBCommand.Parameters.Add(p_sis)
        End If
        Dim p_opc As SqlParameter = New SqlParameter("@p_opc", SqlDbType.Int)
        If IsDBNull(p_opcion) = False And Len(p_opcion) > 0 And p_opcion > 0 Then
            p_opc.Value = p_opcion
            DBCommand.Parameters.Add(p_opc)
        End If

        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
Public Function grid_opc_bar(ByVal p_sistema As String, ByVal p_opcion As Integer, ByVal p_opc_bar As String) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "grid_Opc_Bar"
        Dim p_sis As SqlParameter = New SqlParameter("@p_apl", SqlDbType.VarChar)
        If IsDBNull(p_sistema) = False And Len(p_sistema) > 0 Then
            p_sis.Value = p_sistema
            DBCommand.Parameters.Add(p_sis)
        End If
        Dim p_opc As SqlParameter = New SqlParameter("@p_opc", SqlDbType.Int)
        If IsDBNull(p_opcion) = False And Len(p_opcion) > 0 And p_opcion > 0 Then
            p_opc.Value = p_opcion
            DBCommand.Parameters.Add(p_opc)
        End If
        Dim p_opcbar As SqlParameter = New SqlParameter("@p_opc_bar", SqlDbType.VarChar)
        If IsDBNull(p_sistema) = False And Len(p_sistema) > 0 Then
            p_opcbar.Value = p_opc_bar
            DBCommand.Parameters.Add(p_opcbar)
        End If
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
    Public Function obtenermenu(ByVal p_sistema As String, ByVal p_perfil As Integer) As DataSet
        'Dim dt As New DataTable
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "ObtenerOpcionesMenu"
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        p_sis.Value = p_sistema
        DBCommand.Parameters.Add(p_sis)
        Dim p_per As SqlParameter = New SqlParameter("@Perfil", SqlDbType.Int)
        If (IsDBNull(p_perfil) = False And Len(p_perfil) > 0) And p_perfil > 0 Then
            p_per.Value = p_perfil
            DBCommand.Parameters.Add(p_per)
        End If
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
    Public Function obtenerperfil(ByVal p_usuario As String, ByVal p_sistema As String) As DataSet
        'Dim dt As New DataTable
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "Obtenerperfil"
        Dim p_usu As SqlParameter = New SqlParameter("@usuario", SqlDbType.VarChar)
        p_usu.Value = p_usuario
        DBCommand.Parameters.Add(p_usu)
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        p_sis.Value = p_sistema
        DBCommand.Parameters.Add(p_sis)
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
    Public Function obtenerToolbar(ByVal p_sistema As String, ByVal p_perfil As Integer, _
                                   ByVal p_opcion As Integer) As DataSet
        'Dim dt As New DataTable
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "ObtenerToolbar"
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        p_sis.Value = p_sistema
        DBCommand.Parameters.Add(p_sis)
        Dim p_per As SqlParameter = New SqlParameter("@perfil", SqlDbType.Int)
        p_per.Value = p_perfil
        DBCommand.Parameters.Add(p_per)
        Dim p_opc As SqlParameter = New SqlParameter("@opcion", SqlDbType.Int)
        p_opc.Value = p_opcion
        DBCommand.Parameters.Add(p_opc)
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
     Public Function obtlisAplic(ByVal p_sistema As String) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "ObtLisApl"
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        If IsDBNull(p_sistema) = False And Len(p_sistema) > 0 Then
            p_sis.Value = p_sistema
            DBCommand.Parameters.Add(p_sis)
        End If
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
   Public Function obtlisper(ByVal p_sistema As String, ByVal p_perfil As Integer) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "ObtLisPerfil"
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        If IsDBNull(p_sistema) = False And Len(p_sistema) > 0 Then
            p_sis.Value = p_sistema
            DBCommand.Parameters.Add(p_sis)
        End If
        Dim p_per As SqlParameter = New SqlParameter("@perfil", SqlDbType.Int)
        If IsDBNull(p_perfil) = False And Len(p_perfil) > 0 And p_perfil > 0 Then
            p_per.Value = p_perfil
            DBCommand.Parameters.Add(p_per)
        End If
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
   Public Function obtlistoolbar(ByVal p_lista As String, ByVal p_sistema As String, ByVal p_opcion As String) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "ObtListoolb"
        Dim p_lis As SqlParameter = New SqlParameter("@p_lista", SqlDbType.VarChar)
        p_lis.Value = p_lista
        DBCommand.Parameters.Add(p_lis)
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        If IsDBNull(p_sistema) = False And Len(p_sistema) > 0 Then
            p_sis.Value = p_sistema
            DBCommand.Parameters.Add(p_sis)
        End If
        Dim p_opc As SqlParameter = New SqlParameter("@opcion", SqlDbType.VarChar)
        If IsDBNull(p_opcion) = False And Len(p_opcion) > 0 Then
            p_opc.Value = p_opcion
            DBCommand.Parameters.Add(p_opc)
        End If
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function


    <WebMethod()> _
   Public Function updperfil(ByVal p_ope As String, ByVal p_sistema As String, ByVal p_perfil As Integer, ByVal p_nom_per As String) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "UpdPerfil"
        Dim p_oper As SqlParameter = New SqlParameter("@Proceso", SqlDbType.VarChar)
        p_oper.Value = p_ope
        DBCommand.Parameters.Add(p_oper)
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        p_sis.Value = p_sistema
        DBCommand.Parameters.Add(p_sis)
        Dim p_per As SqlParameter = New SqlParameter("@perfil", SqlDbType.Int)
        p_per.Value = p_perfil
        DBCommand.Parameters.Add(p_per)
        Dim p_nom As SqlParameter = New SqlParameter("@Nomper", SqlDbType.VarChar)
        p_nom.Value = p_nom_per
        DBCommand.Parameters.Add(p_nom)
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
   Public Function updapl(ByVal p_ope As String, ByVal p_sistema As String, ByVal p_nom_apl As String, _
                  ByVal p_men_bie As String) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "Updapl"
        Dim p_oper As SqlParameter = New SqlParameter("@Proceso", SqlDbType.VarChar)
        p_oper.Value = p_ope
        DBCommand.Parameters.Add(p_oper)
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        p_sis.Value = p_sistema
        DBCommand.Parameters.Add(p_sis)
        Dim p_napl As SqlParameter = New SqlParameter("@Nomapli", SqlDbType.VarChar)
        p_napl.Value = p_nom_apl
        DBCommand.Parameters.Add(p_napl)
        Dim p_mbie As SqlParameter = New SqlParameter("@men_bie", SqlDbType.VarChar)
        p_mbie.Value = p_men_bie
        DBCommand.Parameters.Add(p_mbie)
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
   Public Function updaplmenu(ByVal p_ope As String, ByVal p_sistema As String, ByVal p_cod_opc As Integer, _
                         ByVal p_nom_pag As String, ByVal p_nom_ima As String, ByVal p_nombre As String, _
                         ByVal p_padreopc As Integer, ByVal p_posicion As Integer, _
                         ByVal p_activo As Integer, ByVal p_obs As String) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "updaplmenu"
        Dim p_oper As SqlParameter = New SqlParameter("@Proceso", SqlDbType.VarChar)
        p_oper.Value = p_ope
        DBCommand.Parameters.Add(p_oper)
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        p_sis.Value = p_sistema
        DBCommand.Parameters.Add(p_sis)
        Dim p_opc As SqlParameter = New SqlParameter("@cod_opc", SqlDbType.Int)
        p_opc.Value = p_cod_opc
        DBCommand.Parameters.Add(p_opc)
        Dim p_pag As SqlParameter = New SqlParameter("@nom_pag", SqlDbType.VarChar)
        p_pag.Value = p_nom_pag
        DBCommand.Parameters.Add(p_pag)
        Dim p_ima As SqlParameter = New SqlParameter("@nom_ima", SqlDbType.VarChar)
        p_ima.Value = p_nom_ima
        DBCommand.Parameters.Add(p_ima)
        Dim p_nom As SqlParameter = New SqlParameter("@nombre", SqlDbType.VarChar)
        p_nom.Value = p_nombre
        DBCommand.Parameters.Add(p_nom)
        Dim p_popc As SqlParameter = New SqlParameter("@padreopc", SqlDbType.Int)
        p_popc.Value = p_padreopc
        DBCommand.Parameters.Add(p_popc)
        Dim p_pos As SqlParameter = New SqlParameter("@posicion", SqlDbType.Int)
        p_pos.Value = p_posicion
        DBCommand.Parameters.Add(p_pos)
        Dim p_act As SqlParameter = New SqlParameter("@activo", SqlDbType.Int)
        p_act.Value = p_activo
        DBCommand.Parameters.Add(p_act)
        Dim p_obse As SqlParameter = New SqlParameter("@obs", SqlDbType.VarChar)
        p_obse.Value = p_obs
        DBCommand.Parameters.Add(p_obse)
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
   Public Function updapltoolb(ByVal p_ope As String, ByVal p_sistema As String, ByVal p_cod_opc As Integer, _
                         ByVal p_opc_bar As Integer, ByVal p_nombre As String, ByVal p_nom_ima As String) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "updapltoolb"
        Dim p_oper As SqlParameter = New SqlParameter("@Proceso", SqlDbType.VarChar)
        p_oper.Value = p_ope
        DBCommand.Parameters.Add(p_oper)
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        p_sis.Value = p_sistema
        DBCommand.Parameters.Add(p_sis)
        Dim p_opc As SqlParameter = New SqlParameter("@cod_opc", SqlDbType.Int)
        p_opc.Value = p_cod_opc
        DBCommand.Parameters.Add(p_opc)
        Dim p_opcbar As SqlParameter = New SqlParameter("@opc_bar", SqlDbType.Int)
        p_opcbar.Value = p_opc_bar
        DBCommand.Parameters.Add(p_opcbar)
        Dim p_nom As SqlParameter = New SqlParameter("@nombre", SqlDbType.VarChar)
        p_nom.Value = p_nombre
        DBCommand.Parameters.Add(p_nom)
        Dim p_ima As SqlParameter = New SqlParameter("@nom_ima", SqlDbType.VarChar)
        p_ima.Value = p_nom_ima
        DBCommand.Parameters.Add(p_ima)
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
   Public Function obtlisasigmenu(ByVal p_sistema As String, ByVal p_perfil As Integer) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "ObtLisasigmenu"
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        If IsDBNull(p_sistema) = False And Len(p_sistema) > 0 Then
            p_sis.Value = p_sistema
            DBCommand.Parameters.Add(p_sis)
        End If
        Dim p_per As SqlParameter = New SqlParameter("@perfil", SqlDbType.Int)
        If IsDBNull(p_perfil) = False And Len(p_perfil) > 0 And p_perfil > 0 Then
            p_per.Value = p_perfil
            DBCommand.Parameters.Add(p_per)
        End If
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function

    <WebMethod()> _
Public Function obtlisasigtoolb(ByVal p_sistema As String, ByVal p_opcion As Integer, ByVal p_perfil As Integer) As DataSet
        ' llenamos la lista de Sistemas
        DBConn = New SqlConnection(Conn_String)
        DBAdapter = New SqlDataAdapter()
        DBCommand.Connection = DBConn
        DBCommand.CommandType = CommandType.StoredProcedure
        DBCommand.CommandText = "ObtLisasigtoolb"
        Dim p_sis As SqlParameter = New SqlParameter("@Sistema", SqlDbType.VarChar)
        If IsDBNull(p_sistema) = False And Len(p_sistema) > 0 Then
            p_sis.Value = p_sistema
            DBCommand.Parameters.Add(p_sis)
        End If
        Dim p_opc As SqlParameter = New SqlParameter("@opcion", SqlDbType.Int)
        If IsDBNull(p_opcion) = False And Len(p_opcion) > 0 And p_opcion > 0 Then
            p_opc.Value = p_opcion
            DBCommand.Parameters.Add(p_opc)
        End If
        Dim p_per As SqlParameter = New SqlParameter("@perfil", SqlDbType.Int)
        If IsDBNull(p_perfil) = False And Len(p_perfil) > 0 And p_perfil > 0 Then
            p_per.Value = p_perfil
            DBCommand.Parameters.Add(p_per)
        End If
        'llenamos el datatable
        DBAdapter.SelectCommand = DBCommand
        DBAdapter.Fill(DS)
        Return DS
    End Function
End Class
