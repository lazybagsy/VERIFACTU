xmlport 50113 "RC-Hash Test Data"
{
    Caption = 'Hash Test Data';
    Direction = Export;
    Format = Xml;
    Encoding = UTF8;

    schema
    {
        textelement(Root)
        {
            tableelement(HashTestData; "RC-Hash Test Data")
            {
                fieldelement(IDEmisorFactura; HashTestData.IDEmisorFactura) { }
                fieldelement(NumSerieFactura; HashTestData.NumSerieFactura) { }
                fieldelement(FechaExpedicionFactura; HashTestData.FechaExpedicionFactura) { }
                fieldelement(TipoFactura; HashTestData.TipoFactura) { }
                fieldelement(CuotaTotal; HashTestData.CuotaTotal) { }
                fieldelement(ImporteTotal; HashTestData.ImporteTotal) { }
                fieldelement(Huella; HashTestData.Huella) { }
                fieldelement(FechaHoraHusoGenRegistro; HashTestData.FechaHoraHusoGenRegistro) { }
            }
        }
    }
}