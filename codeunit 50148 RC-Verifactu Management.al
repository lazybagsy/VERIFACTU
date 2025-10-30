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
        // Crear marca de tiempo única para usar de forma consistente
        Timestamp := CurrentDateTime;

        HashString := BuildHashString(SalesInvHeader, Timestamp, "Corrected Invoice");
        SalesInvHeader."RC-Verifactu Hash" := CalculateSHA256Hash(HashString);
        SalesInvHeader."RC-Verifactu Timestamp" := Timestamp;
        SalesInvHeader.Modify();

        // También actualizar tabla 50138 con los datos de la factura
        CompanyInfo.Get();

        // Calcular CalcFields para Importe e Importe IVA incluido
        SalesInvHeader.CalcFields(Amount, "Amount Including VAT");
        CuotaTotal := SalesInvHeader."Amount Including VAT" - SalesInvHeader.Amount;

        // Primero, desactivar cualquier registro anterior con el indicador booleano establecido
        PreviousHashTestData.Reset();
        PreviousHashTestData.SetRange("Ult. huella utilizado", true);
        if PreviousHashTestData.FindFirst() then begin
            PreviousHashTestData."Ult. huella utilizado" := false;
            PreviousHashTestData.Modify(true);
        end;

        // Ahora insertar el nuevo registro con una variable limpia
        HashTestData.Init();
        HashTestData."IDEmisorFactura" := CompanyInfo."VAT Registration No.";
        HashTestData."NumSerieFactura" := SalesInvHeader."No.";
        HashTestData."FechaExpedicionFactura" := SalesInvHeader."Posting Date";
        HashTestData."CuotaTotal" := CuotaTotal;
        HashTestData."ImporteTotal" := SalesInvHeader."Amount Including VAT";
        HashTestData."Huella" := SalesInvHeader."RC-Verifactu Hash";
        HashTestData."FechaHoraHusoGenRegistro" := Timestamp;
        if "Corrected Invoice" then
            HashTestData."TipoFactura" := 'R1'  // R1 indica una factura rectificativa
        else
            HashTestData."TipoFactura" := 'F1';
        HashTestData."Ult. huella utilizado" := true;  // Establecer a true en inserción
        HashTestData.Insert(true);
    end;

    // Agregar los procedimientos BuildHashString y CalculateSHA256Hash aquí
    local procedure BuildHashString(SalesInvHeader: Record "Sales Invoice Header"; Timestamp: DateTime; CorrectedInvoice: Boolean) HashString: Text
    var
        CompanyInfo: Record "Company Information";
        PreviousInvoice: Record "Sales Invoice Header";
        CuotaTotal: Decimal;
        TipoFactura: Text;
    begin
        CompanyInfo.Get();

        // Calcular CalcFields para Importe e Importe IVA incluido
        SalesInvHeader.CalcFields(Amount, "Amount Including VAT");

        // Calcular importe de IVA (CuotaTotal = Importe con IVA - Importe)
        CuotaTotal := SalesInvHeader."Amount Including VAT" - SalesInvHeader.Amount;

        // Establecer TipoFactura según tipo de documento
        if CorrectedInvoice then
            TipoFactura := 'R1' // Factura rectificativa
        else
            TipoFactura := 'F1'; // Valor por defecto para factura estándar

        // Solo verificar encadenamiento de hash de factura anterior si no es factura rectificativa
        if not CorrectedInvoice then begin
            // Verificar si existe una factura anterior con hash (para encadenamiento de hash)
            // Encontrar factura anterior basada en ordenación de Nº Serie
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
            // Para facturas rectificativas, usar hash de factura actual
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
        // Formatear con 2 decimales y usar punto como separador decimal
        DecimalString := Format(Value, 0, '<Precision,2:2><Standard Format,9>');

        // Asegurar uso de '.' como separador decimal (reemplazar coma si está presente)
        DecimalString := ConvertStr(DecimalString, ',', '.');

        // Eliminar cualquier separador de miles
        DecimalString := DelChr(DecimalString, '=', ' ');

        exit(DecimalString);
    end;

    local procedure EscapeXmlText(InputText: Text): Text
    var
        EscapedText: Text;
    begin
        // Escapar caracteres especiales XML para evitar errores de codificación
        EscapedText := InputText;
        EscapedText := EscapedText.Replace('&', '&amp;');
        EscapedText := EscapedText.Replace('<', '&lt;');
        EscapedText := EscapedText.Replace('>', '&gt;');
        EscapedText := EscapedText.Replace('"', '&quot;');
        EscapedText := EscapedText.Replace('''', '&apos;');

        // Eliminar o reemplazar cualquier carácter no imprimible que pueda causar problemas de codificación
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
    /// Generar documento XML Verifactu con firma digital XAdES
    /// Similar a la funcionalidad Java XAdES4j
    /// </summary>
    procedure GenerateSignedVerifactuXML(SalesInvHeader: Record "Sales Invoice Header"; var SignedXMLText: Text): Boolean
    var
        XmlDoc: XmlDocument;
        Success: Boolean;
    begin
        // Generar el documento XML base
        if not CreateVerifactuXMLDocumentSimple(SalesInvHeader, XmlDoc) then
            exit(false);

        // Aplicar firma digital XAdES
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

        // Obtener hash anterior para encadenamiento
        PreviousHashTestData.Reset();
        PreviousHashTestData.SetRange("Ult. huella utilizado", true);
        if PreviousHashTestData.FindFirst() and (PreviousHashTestData."NumSerieFactura" <> SalesInvHeader."No.") then
            PreviousHash := PreviousHashTestData."Huella"
        else
            PreviousHash := '';

        Customer.Get(SalesInvHeader."Sell-to Customer No.");

        // Construir XML como texto (enfoque más simple)
        NamespaceUri := 'https://www2.agenciatributaria.gob.es/static_files/common/internet/dep/aplicaciones/es/aeat/tike/cont/ws/SuministroInformacion.xsd';

        XmlText := '<?xml version="1.0" encoding="UTF-8"?>' +
                   '<sum1:RegistroAlta xmlns:sum1="' + NamespaceUri + '">' +
                   '<sum1:IDVersion>1.0</sum1:IDVersion>' +
                   '<sum1:IDFactura>' +
                   '<sum1:IDEmisorFactura>' + EscapeXmlText(CompanyInfo."VAT Registration No.") + '</sum1:IDEmisorFactura>' +
                   '<sum1:NumSerieFactura>' + EscapeXmlText(SalesInvHeader."No.") + '</sum1:NumSerieFactura>' +
                   '<sum1:FechaExpedicionFactura>' + FormatDate(SalesInvHeader."Posting Date") + '</sum1:FechaExpedicionFactura>' +
                   '</sum1:IDFactura>' +
                   '<sum1:NombreRazonEmisor>' + EscapeXmlText(CompanyInfo.Name) + '</sum1:NombreRazonEmisor>' +
                   '<sum1:Subsanacion>N</sum1:Subsanacion>' +
                   '<sum1:RechazoPrevio>N</sum1:RechazoPrevio>' +
                   '<sum1:TipoFactura>F1</sum1:TipoFactura>' +
                   '<sum1:TipoRectificativa/>' +
                   '<sum1:FacturasRectificadas/>' +
                   '<sum1:FacturasSustituidas/>' +
                   '<sum1:ImporteRectificacion/>' +
                   '<sum1:FechaOperacion>' + FormatDate(SalesInvHeader."Posting Date") + '</sum1:FechaOperacion>' +
                   '<sum1:DescripcionOperacion>Venta de mercancias</sum1:DescripcionOperacion>' +
                   '<sum1:Destinatarios>' +
                   '<sum1:IDDestinatario>' +
                   '<sum1:NombreRazonDestinatario>' + EscapeXmlText(Customer.Name) + '</sum1:NombreRazonDestinatario>' +
                   '<sum1:NIFDestinatario>' + EscapeXmlText(Customer."VAT Registration No.") + '</sum1:NIFDestinatario>' +
                   '</sum1:IDDestinatario>' +
                   '</sum1:Destinatarios>' +
                   BuildDesgloseXML(SalesInvHeader) +
                   '<sum1:CuotaTotal>' + FormatDecimal(CuotaTotal) + '</sum1:CuotaTotal>' +
                   '<sum1:ImporteTotal>' + FormatDecimal(SalesInvHeader."Amount Including VAT") + '</sum1:ImporteTotal>';

        // Agregar encadenamiento si existe hash anterior
        if PreviousHash <> '' then
            XmlText += '<sum1:Encadenamiento>' +
                       '<sum1:RegistroAnterior>' +
                       '<sum1:IDEmisorFactura>' + EscapeXmlText(PreviousHashTestData."IDEmisorFactura") + '</sum1:IDEmisorFactura>' +
                       '<sum1:NumSerieFactura>' + EscapeXmlText(PreviousHashTestData."NumSerieFactura") + '</sum1:NumSerieFactura>' +
                       '<sum1:FechaExpedicionFactura>' + FormatDate(PreviousHashTestData."FechaExpedicionFactura") + '</sum1:FechaExpedicionFactura>' +
                       '<sum1:Huella>' + PreviousHash + '</sum1:Huella>' +
                       '</sum1:RegistroAnterior>' +
                       '</sum1:Encadenamiento>';

        XmlText += '<sum1:SistemaInformatico>' +
                   '<sum1:NombreRazon>' + EscapeXmlText(CompanyInfo.Name) + '</sum1:NombreRazon>' +
                   '<sum1:NIF>' + EscapeXmlText(CompanyInfo."VAT Registration No.") + '</sum1:NIF>' +
                   '<sum1:NombreSistemaInformatico>Microsoft Dynamics 365 Business Central</sum1:NombreSistemaInformatico>' +
                   '<sum1:IdSistemaInformatico>BC001</sum1:IdSistemaInformatico>' +
                   '<sum1:Version>1.0</sum1:Version>' +
                   '<sum1:NumeroInstalacion>001</sum1:NumeroInstalacion>' +
                   '<sum1:TipoUsoPosibleSoloVerifactu>S</sum1:TipoUsoPosibleSoloVerifactu>' +
                   '<sum1:TipoUsoPosibleMultiOT>N</sum1:TipoUsoPosibleMultiOT>' +
                   '<sum1:IndicadorMultiplesOT>N</sum1:IndicadorMultiplesOT>' +
                   '</sum1:SistemaInformatico>' +
                   '<sum1:FechaHoraHusoGenRegistro>' + FormatDateTime(Timestamp) + '</sum1:FechaHoraHusoGenRegistro>' +
                   '<sum1:TipoHuella>01</sum1:TipoHuella>' +
                   '<sum1:Huella>' + SalesInvHeader."RC-Verifactu Hash" + '</sum1:Huella>' +
                   '</sum1:RegistroAlta>';

        // Analizar el texto XML en XmlDocument
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
        // Obtener detalles de IVA de las líneas de factura
        SalesInvLine.Reset();
        SalesInvLine.SetRange("Document No.", SalesInvHeader."No.");
        SalesInvLine.SetFilter("VAT %", '>0');

        if SalesInvLine.FindSet() then begin
            repeat
                BaseImponible += SalesInvLine.Amount;
                TipoImpositivo := SalesInvLine."VAT %";
                CuotaImpuesto += SalesInvLine."Amount Including VAT" - SalesInvLine.Amount;
            until SalesInvLine.Next() = 0;

            DesgloseXML := '<sum1:Desglose>' +
                          '<sum1:DetalleDesglose>' +
                          '<sum1:Impuesto>01</sum1:Impuesto>' +
                          '<sum1:ClaveRegimen>01</sum1:ClaveRegimen>' +
                          '<sum1:CalificacionOperacion>S1</sum1:CalificacionOperacion>' +
                          '<sum1:TipoImpositivo>' + FormatDecimal(TipoImpositivo) + '</sum1:TipoImpositivo>' +
                          '<sum1:BaseImponibleOImporteSujeto>' + FormatDecimal(BaseImponible) + '</sum1:BaseImponibleOImporteSujeto>' +
                          '<sum1:CuotaRepercutida>' + FormatDecimal(CuotaImpuesto) + '</sum1:CuotaRepercutida>' +
                          '</sum1:DetalleDesglose>' +
                          '</sum1:Desglose>';
        end else begin
            DesgloseXML := '<sum1:Desglose>' +
                          '<sum1:DetalleDesglose>' +
                          '<sum1:Impuesto>01</sum1:Impuesto>' +
                          '<sum1:ClaveRegimen>01</sum1:ClaveRegimen>' +
                          '<sum1:CalificacionOperacion>S1</sum1:CalificacionOperacion>' +
                          '<sum1:TipoImpositivo>0.00</sum1:TipoImpositivo>' +
                          '<sum1:BaseImponibleOImporteSujeto>' + FormatDecimal(SalesInvHeader.Amount) + '</sum1:BaseImponibleOImporteSujeto>' +
                          '<sum1:CuotaRepercutida>0.00</sum1:CuotaRepercutida>' +
                          '</sum1:DetalleDesglose>' +
                          '</sum1:Desglose>';
        end;

        exit(DesgloseXML);
    end;

    local procedure ApplyXAdESSignatureSimple(var XmlDoc: XmlDocument; var SignedXMLText: Text): Boolean
    var
        UnsignedXML: Text;
    begin
        // Convertir documento XML a texto
        XmlDoc.WriteTo(UnsignedXML);

        // En una implementación real, necesitaría:
        // 1. Obtener el certificado digital de Gestión de Certificados
        // 2. Aplicar firma XAdES-EPES usando biblioteca o servicio externo
        // 3. Por ahora, simularemos este proceso

        // TODO: Implementar firma digital XAdES real
        // Esto requeriría integración con:
        // - Almacén de certificados digitales (Windows Certificate Store o archivos PKCS#12)
        // - Biblioteca de firma XAdES (biblioteca .NET externa o servicio web)
        // - Autoridad de sellado de tiempo (TSA) para sellos de tiempo cualificados

        // Para demostración, devolver el XML sin firmar con marcador de posición de firma
        SignedXMLText := UnsignedXML;

        // Agregar marcador de posición de firma (en implementación real, esto sería la firma real)
        SignedXMLText := SignedXMLText.Replace('</RegistroAlta>', GetXAdESSignaturePlaceholder() + '</RegistroAlta>');

        exit(true);
    end;

    local procedure GetXAdESSignaturePlaceholder(): Text
    var
        SigningTime: Text;
    begin
        // Formatear tiempo de firma correctamente para evitar problemas de codificación
        SigningTime := Format(CurrentDateTime, 0, '<Year4>-<Month,2>-<Day,2>T<Hours24,2>:<Minutes,2>:<Seconds,2>Z');

        // Este es un marcador de posición para la estructura de firma XAdES real
        // En una implementación real, esto sería generado por el proceso de firma
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
    /// Exportar XML Verifactu firmado a archivo
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
            Message('Error al generar XML firmado para factura %1', SalesInvHeader."No.");
            exit;
        end;

        // Crear archivo para descarga
        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(SignedXML);
        TempBlob.CreateInStream(InStr, TextEncoding::UTF8);

        FileName := StrSubstNo('Verifactu_%1_%2.xml', SalesInvHeader."No.", Format(Today, 0, '<Year4><Month,2><Day,2>'));

        DownloadFromStream(InStr, 'Exportar XML Verifactu', '', 'Archivos XML (*.xml)|*.xml', FileName);
    end;
}
