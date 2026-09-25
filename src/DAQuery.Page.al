/// <summary>
/// Hosts the bridge, and explains itself. Open it (search "Dynamic Assist
/// Query") and the Dynamic Assist extension's query builder opens over it;
/// without the extension, it says where to get it.
/// </summary>
page 77500 "DA Query"
{
    Caption = 'Dynamic Assist Query';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    LinksAllowed = false;

    layout
    {
        area(Content)
        {
            usercontrol(Bridge; "DA Bridge")
            {
                ApplicationArea = All;

                trigger Ready()
                var
                    QueryService: Codeunit "DA Query Service";
                begin
                    CurrPage.Bridge.SetInfo(QueryService.PageInfo());
                end;

                trigger Request(RequestId: Text; Method: Text; Payload: Text)
                var
                    QueryService: Codeunit "DA Query Service";
                    LogWriter: Codeunit "DA Query Log Writer";
                    Started: DateTime;
                    Ok: Boolean;
                    ErrorText: Text;
                begin
                    Started := CurrentDateTime();
                    QueryService.SetRequest(Method, Payload);
                    Ok := QueryService.Run();
                    if not Ok then
                        ErrorText := GetLastErrorText();
                    if Method = 'query' then begin
                        LogWriter.Prepare("DA Query Channel"::"Query Builder", Method, Payload, QueryService.GetLastTableNo(), QueryService.GetLastRowCount(), CurrentDateTime() - Started, Ok, ErrorText);
                        if LogWriter.Run() then;
                    end;
                    if Ok then
                        CurrPage.Bridge.Respond(RequestId, true, QueryService.GetResult())
                    else
                        CurrPage.Bridge.Respond(RequestId, false, ErrorText);
                end;
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(QueryLog)
            {
                Caption = 'Query Log';
                ToolTip = 'See who queried what through Dynamic Assist, and how long it took. Needs the DA QUERY ADMIN permission set.';
                Image = Log;
                RunObject = page "DA Query Log";
            }
        }
    }
}
