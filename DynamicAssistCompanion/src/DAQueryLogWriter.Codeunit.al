/// <summary>
/// Writes one query log entry. Run it with Codeunit.Run, so a log that can't
/// be written (no permission, a read-only session) never breaks the query.
/// </summary>
codeunit 77503 "DA Query Log Writer"
{
    Access = Internal;
    Permissions = tabledata "DA Query Log" = i;

    var
        Pending: Record "DA Query Log";

    trigger OnRun()
    begin
        Pending."Entry No." := 0;
        Pending.Insert();
    end;

    procedure Prepare(Channel: Enum "DA Query Channel"; Method: Text; RequestText: Text; TableNo: Integer; RowCount: Integer; Took: Duration; Ok: Boolean; ErrorText: Text)
    var
        TableMetadata: Record "Table Metadata";
    begin
        Clear(Pending);
        Pending."User ID" := CopyStr(UserId(), 1, MaxStrLen(Pending."User ID"));
        Pending."User Security ID" := UserSecurityId();
        Pending.Company := CopyStr(CompanyName(), 1, MaxStrLen(Pending.Company));
        Pending.Channel := Channel;
        Pending.Method := CopyStr(Method, 1, MaxStrLen(Pending.Method));
        Pending."Table No." := TableNo;
        if (TableNo <> 0) and TableMetadata.Get(TableNo) then
            Pending."Table Name" := TableMetadata.Name;
        Pending.Rows := RowCount;
        Pending."Duration (ms)" := Took;
        Pending.Success := Ok;
        Pending."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(Pending."Error Message"));
        Pending.Request := CopyStr(RequestText, 1, MaxStrLen(Pending.Request));
    end;
}
