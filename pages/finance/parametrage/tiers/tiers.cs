using System;
using System.Web.UI;

public partial class tiers : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        AuthHelper.VerifySession(this);

        if (!AuthHelper.HasPermission("tiers"))
        {
            Response.Redirect("~/pages/error/Error500.aspx", false);
            Context.ApplicationInstance.CompleteRequest();
        }
    }
}
