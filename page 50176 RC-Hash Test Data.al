page 50176 "RC-Hash Test Data"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "RC-Hash Test Data";

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                }
                field("IDEmisorFactura"; Rec."IDEmisorFactura")
                {
                    ApplicationArea = All;
                }
                field("NumSerieFactura"; Rec."NumSerieFactura")
                {
                    ApplicationArea = All;
                }
                field("FechaExpedicionFactura"; Rec."FechaExpedicionFactura")
                {
                    ApplicationArea = All;
                }
                field("TipoFactura"; Rec."TipoFactura")
                {
                    ApplicationArea = All;
                }
                field("CuotaTotal"; Rec."CuotaTotal")
                {
                    ApplicationArea = All;
                }
                field("ImporteTotal"; Rec."ImporteTotal")
                {
                    ApplicationArea = All;
                }
                field("Huella"; Rec."Huella")
                {
                    ApplicationArea = All;
                }
                field("FechaHoraHusoGenRegistro"; Rec."FechaHoraHusoGenRegistro")
                {
                    ApplicationArea = All;
                }
                field("Ult. huella utilizado"; Rec."Ult. huella utilizado")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(CalculateHash)
            {
                ApplicationArea = All;
                Caption = 'Calculate Hash';
                Image = CalculateHierarchy;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    GenerateHash();
                end;
            }
            action(ExportXML)
            {
                ApplicationArea = All;
                Caption = 'Export XML';
                Image = Export;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    HashTestData: Record "RC-Hash Test Data";
                begin
                    HashTestData.Reset();
                    HashTestData.SetRange("Entry No.", Rec."Entry No.");
                    XMLPORT.Run(50113, false, false, HashTestData);
                end;
            }
            action(GenerateQRCode)
            {
                ApplicationArea = All;
                Caption = 'Generate QR Code';
                Image = SparkleFilled;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    QRCodeURL: Text;
                    QRCodeDisplay: Page "RC-QR Code Display";
                begin
                    QRCodeURL := BuildQRCodeURL();

                    // Display QR Code in a page
                    QRCodeDisplay.SetQRCodeURL(QRCodeURL);
                    QRCodeDisplay.RunModal();
                end;
            }
        }
    }

    local procedure GenerateHash()
    var
        DotNet_StringBuilder: Codeunit DotNet_StringBuilder;
        HashString: Text;
        TypeHelper: Codeunit "Type Helper";
    begin
        HashString := BuildHashString();
        Rec.Huella := CalculateSHA256Hash(HashString);
        Rec.Modify(true);
    end;

    local procedure BuildHashString() HashString: Text
    begin
        HashString := 'IDEmisorFactura=' + Rec.IDEmisorFactura +
                      '&NumSerieFactura=' + Rec.NumSerieFactura +
                      '&FechaExpedicionFactura=' + FormatDate(Rec.FechaExpedicionFactura) +
                      '&TipoFactura=' + Rec.TipoFactura +
                      '&CuotaTotal=' + FormatDecimal(Rec.CuotaTotal) +
                      '&ImporteTotal=' + FormatDecimal(Rec.ImporteTotal) +
                      '&Huella=' +
                      '&FechaHoraHusoGenRegistro=' + FormatDateTime(Rec.FechaHoraHusoGenRegistro);
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

    local procedure BuildQRCodeURL(): Text
    var
        BaseURL: Text;
        QRCodeString: Text;
    begin
        // Base URL for QR code validation
        // BaseURL := 'https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQR?';
        BaseURL := 'https://prewww2.aeat.es/wlpl/TIKE-CONT/ValidarQRNoVerifactu?';

        // Build the QR code string with parameters
        /* QRCodeString := CodificarQR(
            BaseURL,
            Rec.IDEmisorFactura,
            Rec.NumSerieFactura,
            Format(Rec.FechaExpedicionFactura, 0, '<Day,2>-<Month,2>-<Year4>'),
            Format(Rec.ImporteTotal, 0, '<Precision,2:2><Standard Format,9>')
        ); */
        QRCodeString := CodificarQR(
            BaseURL,
            'B16388340',
            '12345678&G33',
            '01-01-2024',
            '241.4'
        );

        exit(QRCodeString);
    end;

    local procedure CodificarQR(Prefijo: Text; NIF: Text; NumSerie: Text; Fecha: Text; Importe: Text): Text
    var
        EncodedNIF: Text;
        EncodedNumSerie: Text;
        EncodedFecha: Text;
        EncodedImporte: Text;
        Result: Text;
    begin
        // Encode each parameter
        EncodedNIF := EncodeParam(NIF);
        EncodedNumSerie := EncodeParam(NumSerie);
        EncodedFecha := EncodeParam(Fecha);
        EncodedImporte := EncodeParam(Importe);

        // Build the complete URL
        Result := Prefijo + 'nif=' + EncodedNIF +
                  '&numserie=' + EncodedNumSerie +
                  '&fecha=' + EncodedFecha +
                  '&importe=' + EncodedImporte;

        exit(Result);
    end;

    local procedure EncodeParam(Param: Text): Text
    var
        TypeHelper: Codeunit "Type Helper";
    begin
        // URL encode the parameter (UTF-8)
        exit(TypeHelper.UriEscapeDataString(Param));
    end;
}