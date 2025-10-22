page 50177 "RC-QR Code Display"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'QR Code';

    layout
    {
        area(Content)
        {
            group(QRCodeGroup)
            {
                Caption = 'QR Code Information';

                field(QRCodeImage; QRCodeURL)
                {
                    ApplicationArea = All;
                    Caption = 'QR Code Image';
                    ExtendedDatatype = URL;
                    MultiLine = true;
                    Editable = false;

                    trigger OnDrillDown()
                    begin
                        Hyperlink(QRCodeURL);
                    end;
                }

                field(URLDisplay; QRCodeURL)
                {
                    ApplicationArea = All;
                    Caption = 'QR Code URL';
                    MultiLine = true;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenURL)
            {
                ApplicationArea = All;
                Caption = 'Open in Browser';
                Image = Web;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    Hyperlink(QRCodeURL);
                end;
            }

            action(GenerateQRImage)
            {
                ApplicationArea = All;
                Caption = 'Generate QR Image';
                Image = Picture;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    QRImageURL: Text;
                begin
                    // Use QR Server API to generate QR code image
                    QRImageURL := 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=' + GetEncodedURL(QRCodeURL);
                    Message('QR Code Image URL:\%1', QRImageURL);
                    Hyperlink(QRImageURL);
                end;
            }
        }
    }

    var
        QRCodeURL: Text;

    procedure SetQRCodeURL(NewURL: Text)
    begin
        QRCodeURL := NewURL;
    end;

    local procedure GetEncodedURL(URL: Text): Text
    var
        TypeHelper: Codeunit "Type Helper";
    begin
        exit(TypeHelper.UriEscapeDataString(URL));
    end;
}
