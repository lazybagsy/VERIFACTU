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

    local procedure EscapeXmlText(InputText: Text): Text
    var
        EscapedText: Text;
    begin
        // Escape XML special characters to avoid encoding errors
        EscapedText := InputText;
        EscapedText := EscapedText.Replace('&', '&amp;');
        EscapedText := EscapedText.Replace('<', '&lt;');
        EscapedText := EscapedText.Replace('>', '&gt;');
        EscapedText := EscapedText.Replace('"', '&quot;');
        EscapedText := EscapedText.Replace('''', '&apos;');

        // Remove or replace any non-printable characters that might cause encoding issues
        EscapedText := DelChr(EscapedText, '=', DelChr(EscapedText, '=', ' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿ'));

        exit(EscapedText);
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

    /// <summary>
    /// Generate Verifactu XML document with XAdES digital signature
    /// Similar to Java XAdES4j functionality
    /// </summary>
    procedure GenerateSignedVerifactuXML(SalesInvHeader: Record "Sales Invoice Header"; var SignedXMLText: Text): Boolean
    var
        XmlDoc: XmlDocument;
        Success: Boolean;
    begin
        // Generate the base XML document
        if not CreateVerifactuXMLDocumentSimple(SalesInvHeader, XmlDoc) then
            exit(false);

        // Apply XAdES digital signature
        Success := ApplyXAdESSignatureSimple(XmlDoc, SignedXMLText);

        exit(Success);
    end;

    local procedure CreateVerifactuXMLDocumentSimple(SalesInvHeader: Record "Sales Invoice Header"; var XmlDoc: XmlDocument): Boolean
    var
        XmlText: Text;
        CompanyInfo: Record "Company Information";
        Customer: Record Customer;
        CuotaTotal: Decimal;
        Timestamp: DateTime;
        PreviousHashTestData: Record "RC-Hash Test Data";
        PreviousHash: Text;
        NamespaceUri: Text;
    begin
        CompanyInfo.Get();
        SalesInvHeader.CalcFields(Amount, "Amount Including VAT");
        CuotaTotal := SalesInvHeader."Amount Including VAT" - SalesInvHeader.Amount;
        Timestamp := SalesInvHeader."RC-Verifactu Timestamp";
        if Timestamp = 0DT then
            Timestamp := CurrentDateTime;

        // Get previous hash for chaining
        PreviousHashTestData.Reset();
        PreviousHashTestData.SetRange("Ult. huella utilizado", true);
        if PreviousHashTestData.FindFirst() and (PreviousHashTestData."NumSerieFactura" <> SalesInvHeader."No.") then
            PreviousHash := PreviousHashTestData."Huella"
        else
            PreviousHash := '';

        Customer.Get(SalesInvHeader."Sell-to Customer No.");

        // Build XML as text (simpler approach)
        NamespaceUri := 'https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/aplicaciones/es/aeat/tike/cont/ws/SuministroInformacion.xsd';

        XmlText := '<?xml version="1.0" encoding="UTF-8"?>' +
                   '<RegistroAlta xmlns="' + NamespaceUri + '">' +
                   '<IDVersion>1.0</IDVersion>' +
                   '<IDFactura>' +
                   '<IDEmisorFactura>' + EscapeXmlText(CompanyInfo."VAT Registration No.") + '</IDEmisorFactura>' +
                   '<NumSerieFactura>' + EscapeXmlText(SalesInvHeader."No.") + '</NumSerieFactura>' +
                   '<FechaExpedicionFactura>' + FormatDate(SalesInvHeader."Posting Date") + '</FechaExpedicionFactura>' +
                   '</IDFactura>' +
                   '<NombreRazonEmisor>' + EscapeXmlText(CompanyInfo.Name) + '</NombreRazonEmisor>' +
                   '<Subsanacion>N</Subsanacion>' +
                   '<RechazoPrevio>N</RechazoPrevio>' +
                   '<TipoFactura>F1</TipoFactura>' +
                   '<FechaOperacion>' + FormatDate(SalesInvHeader."Posting Date") + '</FechaOperacion>' +
                   '<DescripcionOperacion>Venta de mercancias</DescripcionOperacion>' +
                   '<Destinatarios>' +
                   '<IDDestinatario>' +
                   '<NombreRazonDestinatario>' + EscapeXmlText(Customer.Name) + '</NombreRazonDestinatario>' +
                   '<NIFDestinatario>' + EscapeXmlText(Customer."VAT Registration No.") + '</NIFDestinatario>' +
                   '</IDDestinatario>' +
                   '</Destinatarios>' +
                   BuildDesgloseXML(SalesInvHeader) +
                   '<CuotaTotal>' + FormatDecimal(CuotaTotal) + '</CuotaTotal>' +
                   '<ImporteTotal>' + FormatDecimal(SalesInvHeader."Amount Including VAT") + '</ImporteTotal>';

        // Add chaining if previous hash exists
        if PreviousHash <> '' then
            XmlText += '<Encadenamiento>' +
                       '<RegistroAnterior>' +
                       '<IDEmisorFactura>' + EscapeXmlText(PreviousHashTestData."IDEmisorFactura") + '</IDEmisorFactura>' +
                       '<NumSerieFactura>' + EscapeXmlText(PreviousHashTestData."NumSerieFactura") + '</NumSerieFactura>' +
                       '<FechaExpedicionFactura>' + FormatDate(PreviousHashTestData."FechaExpedicionFactura") + '</FechaExpedicionFactura>' +
                       '<Huella>' + PreviousHash + '</Huella>' +
                       '</RegistroAnterior>' +
                       '</Encadenamiento>';

        XmlText += '<SistemaInformatico>' +
                   '<NombreRazon>' + EscapeXmlText(CompanyInfo.Name) + '</NombreRazon>' +
                   '<NIF>' + EscapeXmlText(CompanyInfo."VAT Registration No.") + '</NIF>' +
                   '<NombreSistemaInformatico>Microsoft Dynamics 365 Business Central</NombreSistemaInformatico>' +
                   '<IdSistemaInformatico>BC001</IdSistemaInformatico>' +
                   '<Version>1.0</Version>' +
                   '<NumeroInstalacion>001</NumeroInstalacion>' +
                   '<TipoUsoPosibleSoloVerifactu>S</TipoUsoPosibleSoloVerifactu>' +
                   '<TipoUsoPosibleMultiOT>N</TipoUsoPosibleMultiOT>' +
                   '<IndicadorMultiplesOT>N</IndicadorMultiplesOT>' +
                   '</SistemaInformatico>' +
                   '<FechaHoraHusoGenRegistro>' + FormatDateTime(Timestamp) + '</FechaHoraHusoGenRegistro>' +
                   '<TipoHuella>01</TipoHuella>' +
                   '<Huella>' + SalesInvHeader."RC-Verifactu Hash" + '</Huella>' +
                   '</RegistroAlta>';

        // Parse the XML text into XmlDocument
        if not XmlDocument.ReadFrom(XmlText, XmlDoc) then
            exit(false);

        exit(true);
    end;

    local procedure BuildDesgloseXML(SalesInvHeader: Record "Sales Invoice Header"): Text
    var
        SalesInvLine: Record "Sales Invoice Line";
        BaseImponible: Decimal;
        TipoImpositivo: Decimal;
        CuotaImpuesto: Decimal;
        DesgloseXML: Text;
    begin
        // Get VAT details from invoice lines
        SalesInvLine.Reset();
        SalesInvLine.SetRange("Document No.", SalesInvHeader."No.");
        SalesInvLine.SetFilter("VAT %", '>0');

        if SalesInvLine.FindSet() then begin
            repeat
                BaseImponible += SalesInvLine.Amount;
                TipoImpositivo := SalesInvLine."VAT %";
                CuotaImpuesto += SalesInvLine."Amount Including VAT" - SalesInvLine.Amount;
            until SalesInvLine.Next() = 0;

            DesgloseXML := '<Desglose>' +
                          '<DetalleDesglose>' +
                          '<Impuesto>01</Impuesto>' +
                          '<ClaveRegimen>01</ClaveRegimen>' +
                          '<CalificacionOperacion>S1</CalificacionOperacion>' +
                          '<BaseImponible>' + FormatDecimal(BaseImponible) + '</BaseImponible>' +
                          '<TipoImpositivo>' + FormatDecimal(TipoImpositivo) + '</TipoImpositivo>' +
                          '<CuotaImpuesto>' + FormatDecimal(CuotaImpuesto) + '</CuotaImpuesto>' +
                          '</DetalleDesglose>' +
                          '</Desglose>';
        end else begin
            DesgloseXML := '<Desglose>' +
                          '<DetalleDesglose>' +
                          '<Impuesto>01</Impuesto>' +
                          '<ClaveRegimen>01</ClaveRegimen>' +
                          '<CalificacionOperacion>S1</CalificacionOperacion>' +
                          '<BaseImponible>' + FormatDecimal(SalesInvHeader.Amount) + '</BaseImponible>' +
                          '<TipoImpositivo>0.00</TipoImpositivo>' +
                          '<CuotaImpuesto>0.00</CuotaImpuesto>' +
                          '</DetalleDesglose>' +
                          '</Desglose>';
        end;

        exit(DesgloseXML);
    end;

    local procedure ApplyXAdESSignatureSimple(var XmlDoc: XmlDocument; var SignedXMLText: Text): Boolean
    var
        UnsignedXML: Text;
    begin
        // Convert XML document to text
        XmlDoc.WriteTo(UnsignedXML);

        // In a real implementation, you would need to:
        // 1. Get the digital certificate from Certificate Management
        // 2. Apply XAdES-EPES signature using external library or service
        // 3. For now, we'll simulate this process

        // TODO: Implement actual XAdES digital signature
        // This would require integration with:
        // - Digital certificate store (Windows Certificate Store or PKCS#12 files)
        // - XAdES signature library (external .NET library or web service)
        // - Timestamp authority (TSA) for qualified timestamps

        // For demonstration, return the unsigned XML with signature placeholder
        SignedXMLText := UnsignedXML;

        // Add signature placeholder (in real implementation, this would be the actual signature)
        SignedXMLText := SignedXMLText.Replace('</RegistroAlta>', GetXAdESSignaturePlaceholder() + '</RegistroAlta>');

        exit(true);
    end;

    local procedure GetXAdESSignaturePlaceholder(): Text
    var
        SigningTime: Text;
    begin
        // Format signing time properly to avoid encoding issues
        SigningTime := Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z');

        // This is a placeholder for the actual XAdES signature structure
        // In a real implementation, this would be generated by the signing process
        exit('<ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">' +
             '<ds:SignedInfo>' +
             '<ds:CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>' +
             '<ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>' +
             '<ds:Reference URI="">' +
             '<ds:Transforms>' +
             '<ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>' +
             '</ds:Transforms>' +
             '<ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>' +
             '<ds:DigestValue>PLACEHOLDER_DIGEST_VALUE</ds:DigestValue>' +
             '</ds:Reference>' +
             '</ds:SignedInfo>' +
             '<ds:SignatureValue>PLACEHOLDER_SIGNATURE_VALUE</ds:SignatureValue>' +
             '<ds:KeyInfo>' +
             '<ds:X509Data>' +
             '<ds:X509Certificate>PLACEHOLDER_CERTIFICATE</ds:X509Certificate>' +
             '</ds:X509Data>' +
             '</ds:KeyInfo>' +
             '<xades:QualifyingProperties xmlns:xades="http://uri.etsi.org/01903/v1.3.2#" Target="#signature">' +
             '<xades:SignedProperties>' +
             '<xades:SignedSignatureProperties>' +
             '<xades:SigningTime>' + SigningTime + '</xades:SigningTime>' +
             '</xades:SignedSignatureProperties>' +
             '</xades:SignedProperties>' +
             '</xades:QualifyingProperties>' +
             '</ds:Signature>');
    end;

    /// <summary>
    /// Export signed Verifactu XML to file
    /// </summary>
    procedure ExportSignedVerifactuXML(SalesInvHeader: Record "Sales Invoice Header")
    var
        SignedXML: Text;
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
        FileName: Text;
    begin
        if not GenerateSignedVerifactuXML(SalesInvHeader, SignedXML) then begin
            Message('Error generating signed XML for invoice %1', SalesInvHeader."No.");
            exit;
        end;

        // Create file for download
        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(SignedXML);
        TempBlob.CreateInStream(InStr, TextEncoding::UTF8);

        FileName := StrSubstNo('Verifactu_%1_%2.xml', SalesInvHeader."No.", Format(Today, 0, '<Year4><Month,2><Day,2>'));

        DownloadFromStream(InStr, 'Export Verifactu XML', '', 'XML Files (*.xml)|*.xml', FileName);
    end;
}
