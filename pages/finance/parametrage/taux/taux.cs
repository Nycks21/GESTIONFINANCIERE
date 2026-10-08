using System;
using System.Web.UI;

public partial class taux : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        AuthHelper.VerifySession(this);

        if (!AuthHelper.HasPermission("taux"))
        {
            Response.Redirect("~/pages/error/Error500.aspx", false);
            Context.ApplicationInstance.CompleteRequest();
        }
    }
}
