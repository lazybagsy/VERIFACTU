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
    }

    trigger OnInsert()
    begin
        // Do nothing on insert - wait for hash to be generated
        // The boolean flag will be set in OnModify when the hash is added
    end;

    trigger OnModify()
    var
        PreviousRecord: Record "RC-Hash Test Data";
    begin
        // When a hash is being set and the flag is not yet true
        if (Rec."Huella" <> '') and (not Rec."Ult. huella utilizado") then begin
            // Find any other record with the flag set to true
            PreviousRecord.Reset();
            PreviousRecord.SetFilter("Entry No.", '<>%1', Rec."Entry No.");
            PreviousRecord.SetRange("Ult. huella utilizado", true);
            if PreviousRecord.FindFirst() then begin
                PreviousRecord."Ult. huella utilizado" := false;
                PreviousRecord.Modify();
            end;

            // Always set this record's flag to true when hash exists
            Rec."Ult. huella utilizado" := true;
        end;
    end;
}