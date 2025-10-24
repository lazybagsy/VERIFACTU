codeunit 50148 "RC-Verifactu Management"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', false, false)]
    local procedure OnAfterPostSalesDoc(var SalesHeader: Record "Sales Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; SalesShptHdrNo: Code[20]; RetRcpHdrNo: Code[20]; SalesInvHdrNo: Code[20]; SalesCrMemoHdrNo: Code[20]; CommitIsSuppressed: Boolean)
    var
        SalesInvHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        if (SalesInvHdrNo = '') and (SalesCrMemoHdrNo = '') then
            exit;

        if (SalesInvHdrNo <> '') then begin
            if SalesInvHeader.Get(SalesInvHdrNo) then
                GenerateVerifactuHash(SalesInvHeader, false);
        end;

        if SalesCrMemoHdrNo <> '' then begin
            if SalesCrMemoHeader.Get("SalesCrMemoHdrNo") then begin
                if (SalesCrMemoHeader."Corrected Invoice No." <> '') then begin
                    if SalesInvHeader.Get(SalesCrMemoHeader."Corrected Invoice No.") then
                        GenerateVerifactuHash(SalesInvHeader, true);
                end;
            end;
        end
    end;

    local procedure GenerateVerifactuHash(var SalesInvHeader: Record "Sales Invoice Header"; "Corrected Invoice": Boolean)
    var
        HashString: Text;
        HashTestData: Record "RC-Hash Test Data";
        PreviousHashTestData: Record "RC-Hash Test Data";
        CompanyInfo: Record "Company Information";
        CuotaTotal: Decimal;
        Timestamp: DateTime;
    begin
        // Create timestamp once to use consistently
        Timestamp := CurrentDateTime;

        HashString := BuildHashString(SalesInvHeader, Timestamp, "Corrected Invoice");
        SalesInvHeader."RC-Verifactu Hash" := CalculateSHA256Hash(HashString);
        SalesInvHeader."RC-Verifactu Timestamp" := Timestamp;
        SalesInvHeader.Modify();

        // Also update table 50138 with the invoice data
        CompanyInfo.Get();

        // Calculate CalcFields for Amount and Amount Including VAT
        SalesInvHeader.CalcFields(Amount, "Amount Including VAT");
        CuotaTotal := SalesInvHeader."Amount Including VAT" - SalesInvHeader.Amount;

        // First, deactivate any previous record with the boolean flag set
        PreviousHashTestData.Reset();
        PreviousHashTestData.SetRange("Ult. huella utilizado", true);
        if PreviousHashTestData.FindFirst() then begin
            PreviousHashTestData."Ult. huella utilizado" := false;
            PreviousHashTestData.Modify(true);
        end;

        // Now insert the new record with a clean variable
        HashTestData.Init();
        HashTestData."IDEmisorFactura" := CompanyInfo."VAT Registration No.";
        HashTestData."NumSerieFactura" := SalesInvHeader."No.";
        HashTestData."FechaExpedicionFactura" := SalesInvHeader."Posting Date";
        HashTestData."CuotaTotal" := CuotaTotal;
        HashTestData."ImporteTotal" := SalesInvHeader."Amount Including VAT";
        HashTestData."Huella" := SalesInvHeader."RC-Verifactu Hash";
        HashTestData."FechaHoraHusoGenRegistro" := Timestamp;
        if "Corrected Invoice" then
            HashTestData."TipoFactura" := 'R1'  // Assuming 'R1' indicates a corrected posted invoice
        else
            HashTestData."TipoFactura" := 'F1';
        HashTestData."Ult. huella utilizado" := true;  // Set to true on insert
        HashTestData.Insert(true);
    end;

    // Add your BuildHashString and CalculateSHA256Hash procedures here
    local procedure BuildHashString(SalesInvHeader: Record "Sales Invoice Header"; Timestamp: DateTime; CorrectedInvoice: Boolean) HashString: Text
    var
        CompanyInfo: Record "Company Information";
        PreviousInvoice: Record "Sales Invoice Header";
        CuotaTotal: Decimal;
        TipoFactura: Text;
    begin
        CompanyInfo.Get();

        // Calculate CalcFields for Amount and Amount Including VAT
        SalesInvHeader.CalcFields(Amount, "Amount Including VAT");

        // Calculate VAT amount (CuotaTotal = Amount Including VAT - Amount)
        CuotaTotal := SalesInvHeader."Amount Including VAT" - SalesInvHeader.Amount;

        // Set TipoFactura based on document type
        if CorrectedInvoice then
            TipoFactura := 'R1' // Corrected invoice
        else
            TipoFactura := 'F1'; // Default to standard invoice

        // Only check for previous invoice hash chaining if it's not a corrected invoice
        if not CorrectedInvoice then begin
            // Check if there's a previous invoice with a hash (for hash chaining)
            // Find previous invoice based on No. Series ordering
            PreviousInvoice.Reset();
            PreviousInvoice.SetCurrentKey("No. Series", "Posting Date");
            PreviousInvoice.SetRange("No. Series", SalesInvHeader."No. Series");
            PreviousInvoice.SetFilter("RC-Verifactu Hash", '<>%1', '');
            PreviousInvoice.SetFilter("Posting Date", '..%1', SalesInvHeader."Posting Date");
            PreviousInvoice.SetFilter("No.", '<%1', SalesInvHeader."No.");

            if PreviousInvoice.FindLast() then
                HashString := 'IDEmisorFactura=' + CompanyInfo."VAT Registration No." +
                              '&NumSerieFactura=' + SalesInvHeader."No." +
                              '&FechaExpedicionFactura=' + FormatDate(SalesInvHeader."Posting Date") +
                              '&TipoFactura=' + TipoFactura +
                              '&CuotaTotal=' + FormatDecimal(CuotaTotal) +
                              '&ImporteTotal=' + FormatDecimal(SalesInvHeader."Amount Including VAT") +
                              '&Huella=' + PreviousInvoice."RC-Verifactu Hash" +
                              '&FechaHoraHusoGenRegistro=' + FormatDateTime(Timestamp)
            else
                HashString := 'IDEmisorFactura=' + CompanyInfo."VAT Registration No." +
                              '&NumSerieFactura=' + SalesInvHeader."No." +
                              '&FechaExpedicionFactura=' + FormatDate(SalesInvHeader."Posting Date") +
                              '&TipoFactura=' + TipoFactura +
                              '&CuotaTotal=' + FormatDecimal(CuotaTotal) +
                              '&ImporteTotal=' + FormatDecimal(SalesInvHeader."Amount Including VAT") +
                              '&Huella=' +
                              '&FechaHoraHusoGenRegistro=' + FormatDateTime(Timestamp);
        end else begin
            // For corrected invoices, use current invoice hash
            HashString := '&IDEmisorFacturaAnulada=' + CompanyInfo."VAT Registration No." +
                          '&NumSerieFacturaAnulada=' + SalesInvHeader."No." +
                          '&FechaExpedicionFacturaAnulada=' + FormatDate(SalesInvHeader."Posting Date") +
                          '&Huella=' + SalesInvHeader."RC-Verifactu Hash" +
                          '&FechaHoraHusoGenRegistro=' + FormatDateTime(Timestamp);
        end;
    end;

    local procedure FormatDate(Value: Date): Text
    begin
        exit(Format(Value, 0, '<Day,2>-<Month,2>-<Year4>'));
    end;

    local procedure FormatDateTime(Value: DateTime): Text
    begin
        exit(Format(Value, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>+01:00'));
    end;

    local procedure FormatDecimal(Value: Decimal): Text
    var
        DecimalString: Text;
        DotPos: Integer;
        IntegerPart: Text;
        DecimalPart: Text;
    begin
        // Format with 2 decimal places and use dot as decimal separator
        DecimalString := Format(Value, 0, '<Precision,2:2><Standard Format,9>');

        // Ensure we use '.' as decimal separator (replace comma if present)
        DecimalString := ConvertStr(DecimalString, ',', '.');

        // Remove any thousand separators
        DecimalString := DelChr(DecimalString, '=', ' ');

        exit(DecimalString);
    end;

    local procedure CalculateSHA256Hash(InputString: Text) HashValue: Text
    var
        CryptoMgmt: Codeunit "Cryptography Management";
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
        HashBytes: Text;
    begin
        // Codificar la cadena en un array de bytes en formato UTF-8
        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(InputString);

        // Obtener el stream de entrada con codificación UTF-8
        TempBlob.CreateInStream(InStr, TextEncoding::UTF8);

        // Generar el hash SHA-256 desde el stream UTF-8
        HashValue := CryptoMgmt.GenerateHash(InStr, 2);  // 2 = SHA256
    end;
}