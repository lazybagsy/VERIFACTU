codeunit 50148 "RC-Verifactu Management"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterSalesInvHeaderInsert', '', false, false)]
    local procedure OnAfterSalesInvHeaderInsert(var SalesInvHeader: Record "Sales Invoice Header"; SalesHeader: Record "Sales Header")
    begin
        if SalesInvHeader.IsTemporary then
            exit;

        GenerateVerifactuHash(SalesInvHeader);
    end;

    local procedure GenerateVerifactuHash(var SalesInvHeader: Record "Sales Invoice Header")
    var
        HashString: Text;
    begin
        HashString := BuildHashString(SalesInvHeader);
        SalesInvHeader."RC-Verifactu Hash" := CalculateSHA256Hash(HashString);
        SalesInvHeader.Modify();
    end;

    // Add your BuildHashString and CalculateSHA256Hash procedures here
    local procedure BuildHashString(SalesInvHeader: Record "Sales Invoice Header") HashString: Text
    var
        CompanyInfo: Record "Company Information";
        CuotaTotal: Decimal;
        TipoFactura: Text;
    begin
        CompanyInfo.Get();

        // Calculate VAT amount (CuotaTotal = Amount Including VAT - Amount)
        CuotaTotal := SalesInvHeader."Amount Including VAT" - SalesInvHeader.Amount;

        // Set TipoFactura based on document type
        TipoFactura := 'F1'; // Default to standard invoice

        HashString := 'IDEmisorFactura=' + CompanyInfo."VAT Registration No." +
                      '&NumSerieFactura=' + SalesInvHeader."No." +
                      '&FechaExpedicionFactura=' + FormatDate(SalesInvHeader."Posting Date") +
                      '&TipoFactura=' + TipoFactura +
                      '&CuotaTotal=' + FormatDecimal(CuotaTotal) +
                      '&ImporteTotal=' + FormatDecimal(SalesInvHeader."Amount Including VAT") +
                      '&Huella=' +
                      '&FechaHoraHusoGenRegistro=' + FormatDateTime(CurrentDateTime);
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