# Delphi - Sending Bitmap directly to ESC/POS #

This is based on http://nicholas.piasecki.name/blog/2009/12/sending-a-bit-image-to-an-epson-tm-t88iii-receipt-printer-using-c-and-escpos/

EDIT: You can access the original article on web.archive.org: http://web.archive.org/web/20141207201042/http://nicholas.piasecki.name/blog/2009/12/sending-a-bit-image-to-an-epson-tm-t88iii-receipt-printer-using-c-and-escpos/

The linked Delphi translation did not work for me, so I worked off the original C# test files provided in the article.

### Example Usage ###

This uses the Synaser library from [Synapse](http://www.ararat.cz/synapse/) to send the buffer directly to a COM Port.

```
#!delphi

uses
  synaser,
  ssESCPOSPrintBitmap;

var
  LDevice : TBlockDevice;
  LBuffer : string;
begin
  LBuffer := #27'@'; // Initialise the printer
  LBuffer := LBuffer + _ESCPosPrintBitmap().RenderBitmap( 'path\to\bitmapfile' );
  LBuffer := #29'V'#1 // Paper cut full
  
  // Send LBuffer to Printer
  LDevice := TBlockSerial.Create();
    try
      LDevice.Config( 115200, 8, 'N', 1, False, False );
      LDevice.Connect( 'COM7' );
      LDevice.SendString( LBuffer  );
    finally
      LDevice.Free();
    end;
end.
```