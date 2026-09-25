/// <summary>
/// The link between the Dynamic Assist browser extension and AL. The extension
/// finds this add-in's frame and posts requests to it; the add-in raises them
/// as the Request event, and the page answers through Respond. It also shows
/// the page itself: what this is, whether the extension is connected, and
/// where to get it.
/// </summary>
controladdin "DA Bridge"
{
    StartupScript = 'src/bridge/bridge.js';
    StyleSheets = 'src/bridge/bridge.css';
    HorizontalStretch = true;
    HorizontalShrink = true;
    VerticalStretch = true;
    VerticalShrink = true;
    RequestedHeight = 720;
    MinimumHeight = 480;

    /// <summary>The add-in has loaded and is listening for the extension.</summary>
    event Ready();

    /// <summary>A request from the extension: info, tables, fields, apis or query.</summary>
    event Request(RequestId: Text; Method: Text; Payload: Text);

    /// <summary>Sends a request's result (JSON) or error message back to the extension.</summary>
    procedure Respond(RequestId: Text; Ok: Boolean; Payload: Text);

    /// <summary>Details for the page: { version, company, user, webService: { published, name } }.</summary>
    procedure SetInfo(Info: Text);
}
