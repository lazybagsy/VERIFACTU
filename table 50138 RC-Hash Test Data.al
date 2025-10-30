table 50138 "RC-Hash Test Data"
{
    Caption = 'Hash Test Data';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "IDEmisorFactura"; Text[20])
        {
            Caption = 'ID Emisor Factura';
        }
        field(3; "NumSerieFactura"; Text[50])
        {
            Caption = 'Num. Serie Factura';
        }
        field(4; "FechaExpedicionFactura"; Date)
        {
            Caption = 'Fecha Expedicion Factura';
        }
        field(5; "TipoFactura"; Code[2])
        {
            Caption = 'Tipo Factura';
        }
        field(6; "CuotaTotal"; Decimal)
        {
            Caption = 'Cuota Total';
            DecimalPlaces = 2 : 2;
        }
        field(7; "ImporteTotal"; Decimal)
        {
            Caption = 'Importe Total';
            DecimalPlaces = 2 : 2;
        }
        field(8; "Huella"; Text[100])
        {
            Caption = 'Huella';
            Editable = false;
        }
        field(9; "FechaHoraHusoGenRegistro"; DateTime)
        {
            Caption = 'Fecha Hora Huso Gen Registro';
        }
        field(10; "Ult. huella utilizado"; Boolean)
        {
            Caption = 'Ult. huella utilizado';
            Editable = false;
        }
    }

    keys
    {
        key(Key1; "Entry No.")
        {
            Clustered = true;
        }
        key(Key2; "FechaHoraHusoGenRegistro")
        {
        }
    }

    trigger OnInsert()
    begin

    end;

    trigger OnModify()
    begin

    end;
}