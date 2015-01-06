{******************************************************************************}
{                                                                              }
{  Unit: ssESCPosPrintBitmap.pas                                               }
{  Summerswell Core                                                            }
{                                                                              }
{  Copyright (C) 2015 Summerswell                                              }
{                                                                              }
{  Author     : bvonfintel                                                     }
{  Original   : 2015/01/06 11:12:30 AM                                         }
{                                                                              }
{******************************************************************************}

{

  This is based on the class provided by:
  http://nicholas.piasecki.name/blog/2009/12/sending-a-bit-image-to-an-epson-tm-t88iii-receipt-printer-using-c-and-escpos/

  The Delphi translation provided (http://nicholas.piasecki.name/blog/wp-content/uploads/2009/12/Delphi-Version.txt.txt)
  did not print to the Epson TM T70

{}

unit ssESCPosPrintBitmap;

interface

type
  // *** -------------------------------------------------------------------------
  // *** INTERFACE: IssESCPosPrintBitmap
  // *** -------------------------------------------------------------------------
  IssESCPosPrintBitmap = interface( IInterface )
    ['{3F279585-6D2E-451F-AF97-76F0E07A70DF}']
    function RenderBitmap( const ABitmapFilename: string ): string;
  end;

  function _ESCPosPrintBitmap(): IssESCPosPrintBitmap;

implementation

uses
  Windows,
  Graphics,
  Math;

type
  TRGBTripleArray = ARRAY[Word] of TRGBTriple;
  pRGBTripleArray = ^TRGBTripleArray; // Use a PByteArray for pf8bit color.

  // *** -------------------------------------------------------------------------
  // *** RECORD:  TBitmapData
  // *** -------------------------------------------------------------------------
  TBitmapData = record
    Dots      : array of Boolean;
    Height    : Integer;
    Width     : Integer;
  end;

  // *** -------------------------------------------------------------------------
  // *** CLASS: TssESCPosPrintBitmap
  // *** -------------------------------------------------------------------------
  TssESCPosPrintBitmap = class( TInterfacedObject, IssESCPosPrintBitmap )
    private
      FLumThreshold : Integer;
      FBitmap       : TBitmap;
      FBitmapData   : TBitmapData;
      procedure LoadBitmapData();
    public
      constructor Create();
      destructor Destroy; override;

      function RenderBitmap( const ABitmapFilename: string ): string;
  end;

const
  C_DEFAULT_THRESHOLD = 127;

function _ESCPosPrintBitmap(): IssESCPosPrintBitmap;
begin
  Result := TssESCPosPrintBitmap.Create();
end;
      

{ TssESCPosPrintBitmap }

{-------------------------------------------------------------------------------
  Procedure: TssESCPosPrintBitmap.Create
  Author:    bvonfintel
  DateTime:  2015.01.06
  Arguments: None
  Result:    None
-------------------------------------------------------------------------------}
constructor TssESCPosPrintBitmap.Create;
begin
  inherited;
  FBitmap       := TBitmap.Create();
  FLumThreshold := C_DEFAULT_THRESHOLD;
end;

{-------------------------------------------------------------------------------
  Procedure: TssESCPosPrintBitmap.Destroy
  Author:    bvonfintel
  DateTime:  2015.01.06
  Arguments: None
  Result:    None
-------------------------------------------------------------------------------}
destructor TssESCPosPrintBitmap.Destroy;
begin
  FBitmap.Free();
  inherited;
end;

{-------------------------------------------------------------------------------
  Procedure: TssESCPosPrintBitmap.LoadBitmapData
  Author:    bvonfintel
  DateTime:  2015.01.06
  Arguments: None
  Result:    None
-------------------------------------------------------------------------------}
procedure TssESCPosPrintBitmap.LoadBitmapData;
var
  LIndex : Integer;
  LX     : Integer;
  LY     : Integer;
  LLine  : pRGBTripleArray;
  LPixel : TRGBTriple;
  LLum   : Integer;
begin
  LIndex := 0;

  FBitmapData.Height := FBitmap.Height;
  FBitmapData.Width  := FBitmap.Width;
  SetLength( FBitmapData.Dots, FBitmap.Width * FBitmap.Height );
  
  for LY := 0 to FBitmap.Height - 1 do begin
    LLine := FBitmap.ScanLine[LY];
    for LX := 0 to FBitmap.Width - 1 do begin
      LPixel := LLine[LX];
      LLum   := Trunc( ( LPixel.rgbtRed * 0.3 ) + ( LPixel.rgbtGreen  * 0.59 ) + ( LPixel.rgbtBlue * 0.11 ) );
      FBitmapData.Dots[LIndex] := ( LLum < FLumThreshold );
      Inc( LIndex );
    end;
  end;
end;

{-------------------------------------------------------------------------------
  Procedure: TssESCPosPrintBitmap.RenderBitmap
  Author:    bvonfintel
  DateTime:  2015.01.06
  Arguments: const ABitmapFilename: string
  Result:    string
-------------------------------------------------------------------------------}
function TssESCPosPrintBitmap.RenderBitmap( const ABitmapFilename: string): string;
var
  LOffset     : Integer;
  LX          : Integer;
  LSlice      : Byte;
  LB          : Integer;
  LK          : Integer;
  LY          : Integer;
  LI          : Integer;
  LV          : Boolean;
  LVI         : Integer;
begin
  // *** load the Bitmap from the file
  FBitmap.LoadFromFile( ABitmapFilename );
  FBitmap.PixelFormat := pf24bit;

  // *** Convert the bitmap to an array of B/W pixels
  LoadBitmapData();


  // *** Set the line spacing to 24 dots, the height of each "stripe" of the
  // *** image that we're drawing
  Result := #27'3'#24;

  LOffset := 0;
  while ( LOffset < FBitmapData.Height ) do begin
    Result := Result + #27;
    Result := Result + '*'; // Bit image mode
    Result := Result + #33; // 24-dot double density
    Result := Result + Char( Lo( FBitmapData.Width ) );
    Result := Result + Char( Hi( FBitmapData.Width ) );

    for LX := 0 to FBitmapData.Width -1 do begin
      for LK := 0 to 2 do begin
        LSlice := 0;
        for LB := 0 to 7 do begin
          LY := ( ( ( LOffset div 8 ) + LK ) * 8 ) + LB;
          LI := ( LY * FBitmapData.Width ) + LX;

          LV := False;
          if ( LI < Length( FBitmapData.Dots ) ) then
            LV := FBitmapData.Dots[LI];

          LVI := IfThen( LV, 1, 0 );

          LSlice := LSlice or ( LVI shl ( 7 - LB ) );
        end;

        Result := Result + Chr( LSlice );
      end;
    end;

    LOffset := LOffset + 24;
    Result := Result + sLineBreak;  
  end;

  // *** Restore the line spacing to the default of 30 dots
  Result := Result + #27'3'#30 + sLineBreak + sLineBreak + sLineBreak;
end;

end.
