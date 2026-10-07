using System;
using System.Web.UI;

public partial class sites : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        AuthHelper.VerifySession(this);

        // Permission module Finance
        if (!AuthHelper.HasPermission("sites"))
        {
            Response.Redirect("~/pages/error/Error500.aspx", false);
            Context.ApplicationInstance.CompleteRequest();
        }
    }
}
