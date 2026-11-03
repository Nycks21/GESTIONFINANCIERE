<%@ Page Language="C#" ContentType="application/json" ResponseEncoding="utf-8" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Data.SqlClient" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    Response.ContentType = "application/json";
    Response.ContentEncoding = new System.Text.UTF8Encoding(false);
    
    try
    {
        bool isBlocked = false;
        string blockedUntil = "";
        
        if (Session["authenticated"] != null && (bool)Session["authenticated"])
        {
            int userId = Session["IDUSER"] != null ? Convert.ToInt32(Session["IDUSER"]) : 0;
            int userRole = Session["USERROLE"] != null ? Convert.ToInt32(Session["USERROLE"]) : -1;
            
            // Les SuperAdmin ne sont jamais bloqués
            if (userRole != 0)
            {
                string connStr = AuthHelper.ConnectionString;
                using (SqlConnection conn = new SqlConnection(connStr))
                {
                    conn.Open();
                    string sql = "SELECT BLOCKED_UNTIL FROM USERS WHERE IDUSER = @id";
                    using (SqlCommand cmd = new SqlCommand(sql, conn))
                    {
                        cmd.Parameters.AddWithValue("@id", userId);
                        object result = cmd.ExecuteScalar();
                        if (result != null && result != DBNull.Value)
                        {
                            DateTime until = Convert.ToDateTime(result);
                            if (until > DateTime.Now)
                            {
                                isBlocked = true;
                                blockedUntil = until.ToString("HH:mm:ss");
                            }
                        }
                    }
                }
            }
        }
        
        Response.Write("{\"success\":true,\"isBlocked\":" + isBlocked.ToString().ToLower() + ",\"blockedUntil\":\"" + blockedUntil + "\"}");
    }
    catch (Exception ex)
    {
        Response.Write("{\"success\":false,\"message\":\"" + ex.Message.Replace("\"", "'") + "\"}");
    }
}
</script>