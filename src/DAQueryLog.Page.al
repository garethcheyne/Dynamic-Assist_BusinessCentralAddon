/// <summary>Who queried what through Dynamic Assist. Needs DA QUERY ADMIN.</summary>
page 77502 "DA Query Log"
{
    Caption = 'Dynamic Assist Query Log';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "DA Query Log";
    SourceTableView = sorting("Entry No.") order(descending);
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field(RunAt; Rec.SystemCreatedAt)
                {
                    Caption = 'Run At';
                    ToolTip = 'When the query ran.';
                }
                field("User ID"; Rec."User ID")
                {
                    ToolTip = 'Who ran it: a person, or the app user of a service calling the REST endpoints.';
                }
                field(Channel; Rec.Channel)
                {
                    ToolTip = 'The query builder in the browser extension, or a REST call (GET or POST).';
                }
                field(Company; Rec.Company)
                {
                    ToolTip = 'The company it ran in.';
                }
                field(Method; Rec.Method)
                {
                    ToolTip = 'query, or a metadata call over REST (tables, fields, apis, info).';
                }
                field("Table No."; Rec."Table No.")
                {
                    ToolTip = 'The table queried.';
                }
                field("Table Name"; Rec."Table Name")
                {
                    ToolTip = 'The table queried.';
                }
                field(Rows; Rec.Rows)
                {
                    ToolTip = 'How many rows came back.';
                }
                field("Duration (ms)"; Rec."Duration (ms)")
                {
                    ToolTip = 'How long it took, in milliseconds.';
                }
                field(Success; Rec.Success)
                {
                    ToolTip = 'Whether it ran. If not, the error says why.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ToolTip = 'Why it failed: a table or field that doesn''t exist, no permission, a bad filter.';
                }
                field(Request; Rec.Request)
                {
                    ToolTip = 'The query as sent (the first 2048 characters).';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DeleteOld)
            {
                Caption = 'Delete Entries Older Than 30 Days';
                ToolTip = 'Keep the log small: removes entries more than 30 days old.';
                Image = Delete;

                trigger OnAction()
                var
                    Log: Record "DA Query Log";
                    ConfirmQst: Label 'Delete query log entries older than 30 days?';
                begin
                    if not Confirm(ConfirmQst) then
                        exit;
                    Log.SetFilter(SystemCreatedAt, '<%1', CreateDateTime(Today() - 30, 0T));
                    Log.DeleteAll();
                end;
            }
        }
        area(Promoted)
        {
            actionref(DeleteOld_Promoted; DeleteOld)
            {
            }
        }
    }
}
