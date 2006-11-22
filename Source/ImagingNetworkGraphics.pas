{
  $Id: ImagingNetworkGraphics.pas,v 1.3 2006/08/31 14:53:33 galfar Exp $
  Vampyre Imaging Library
  by Marek Mauder (pentar@seznam.cz)
  http://imaginglib.sourceforge.net

  The contents of this file are used with permission, subject to the Mozilla
  Public License Version 1.1 (the "License"); you may not use this file except
  in compliance with the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL/MPL-1.1.html

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
  the specific language governing rights and limitations under the License.

  Alternatively, the contents of this file may be used under the terms of the
  GNU Lesser General Public License (the  "LGPL License"), in which case the
  provisions of the LGPL License are applicable instead of those above.
  If you wish to allow use of your version of this file only under the terms
  of the LGPL License and not to allow others to use your version of this file
  under the MPL, indicate your decision by deleting  the provisions above and
  replace  them with the notice and other provisions required by the LGPL
  License.  If you do not delete the provisions above, a recipient may use
  your version of this file under either the MPL or the LGPL License.

  For more information about the LGPL: http://www.gnu.org/copyleft/lesser.html
}

{ This unit contains image format loaders/savers for Network Graphics image
  file formats PNG, MNG, and JNG.}
unit ImagingNetworkGraphics;

interface

{$I ImagingOptions.inc}

uses
  Classes, ImagingTypes, Imaging, ImagingUtility, ImagingFormats, dzlib;

type
  TChar4 = array[0..3] of Char;
  TChar8 = array[0..7] of Char;

  { Basic class for Network Graphics file formats loaders/savers.}
  TNetworkGraphicsFileFormat = class(TImageFileFormat)
  protected
    FSignature: TChar8;
    FPreFilter: LongInt;
    FCompressLevel: LongInt;
    FLossyCompression: LongBool;
    FLossyAlpha: LongBool;
    FQuality: LongInt;
    FProgressive: LongBool;
    function GetSupportedFormats: TImageFormats; override;
    procedure SaveData(Handle: TImagingHandle; const Images: TDynImageDataArray; Index: LongInt); override;
    function MakeCompatible(const Image: TImageData; var Comp: TImageData): Boolean; override;
  public
    constructor Create; override;
    function TestFormat(Handle: TImagingHandle): Boolean; override;
  end;

  { Class for loading Portable Network Graphics Images.
    Loads all types of this image format (all images in png test suite)
    and saves all types with bitcount >= 8 (non-interlaced only).
    Compression level and  filtering can be set by options interface.

    Supported ancillary chunks (loading):
    tRNS, bKGD
    (for indexed images transparency contains alpha values for palette,
    RGB/Gray images with transparency are converted to formats with alpha
    and pixels with transparent color are replaced with background color
    with alpha = 0).}
  TPNGFileFormat = class(TNetworkGraphicsFileFormat)
  protected
    procedure LoadData(Handle: TImagingHandle; var Images: TDynImageDataArray; OnlyFirstLevel: Boolean); override;
    procedure SaveData(Handle: TImagingHandle; const Images: TDynImageDataArray; Index: LongInt); override;
  public
    constructor Create; override;
  end;

{$IFDEF LINK_MNG}
  { Class for loading Multiple Network Graphics files.
    This format has complex animation capabilities but Imaging only
    extracts frames. Individual frames are stored as standard PNG or JNG
    images. Loads all types of these frames stored in IHDR-IEND and
    JHDR-IEND streams (Note that there are MNG chunks
    like BASI which define images but does not contain image data itself,
    those are ignored).
    Imaging saves MNG files as MNG-VLC (very low complexity) so it is basicaly
    an array of image frames without MNG animation chunks. Frames can be saved
    as lossless PNG or lossy JNG images (look at TPNGFileFormat and
    TJNGFileFormat for info). Every frame can be in different data format.
    
    Many frame compression settings can be modified by options interface.}
  TMNGFileFormat = class(TNetworkGraphicsFileFormat)
  protected
    procedure LoadData(Handle: TImagingHandle; var Images: TDynImageDataArray; OnlyFirstLevel: Boolean); override;
    procedure SaveData(Handle: TImagingHandle; const Images: TDynImageDataArray; Index: LongInt); override;
  public
    constructor Create; override;
  end;
{$ENDIF}  

{$IFDEF LINK_JNG}
  { Class for loading JPEG Network Graphics Images.
    Loads all types of this image format (all images in jng test suite)
    and saves all types except 12 bit JPEGs.
    Alpha channel in JNG images is stored separately from color/gray data and
    can be lossy (as JPEG image) or lossless (as PNG image) compressed.
    Type of alpha compression, compression level and quality,
    and filtering can be set by options interface.

    Supported ancillary chunks (loading):
    tRNS, bKGD
    (Images with transparency are converted to formats with alpha
    and pixels with transparent color are replaced with background color
    with alpha = 0).}
  TJNGFileFormat = class(TNetworkGraphicsFileFormat)
  protected
    procedure LoadData(Handle: TImagingHandle; var Images: TDynImageDataArray; OnlyFirstLevel: Boolean); override;
    procedure SaveData(Handle: TImagingHandle; const Images: TDynImageDataArray; Index: LongInt); override;
  public
    constructor Create; override;
  end;
{$ENDIF}

const
  NGDefaultPreFilter = 5;
  NGDefaultCompressLevel = 5;
  NGDefaultLossyAlpha = False;
  NGDefaultLossyCompression = False;
  NGDefaultProgressive = False;
  NGDefaultQuality = 90;
  NGLosslessFormats: TImageFormats = [ifIndex8, ifGray8, ifA8Gray8, ifGray16,
    ifA16Gray16, ifR8G8B8, ifA8R8G8B8, ifR16G16B16, ifA16R16G16B16, ifB16G16R16,
    ifA16B16G16R16];
  NGLossyFormats: TImageFormats = [ifGray8, ifA8Gray8, ifR8G8B8, ifA8R8G8B8];

  SPNGExtensions = 'png';
  SPNGFormatName = 'Portable Network Graphics';
  SMNGExtensions = 'mng';
  SMNGFormatName = 'Multiple Network Graphics';
  SJNGExtensions = 'jng';
  SJNGFormatName = 'JPEG Network Graphics';

implementation

{$IFDEF LINK_JNG}
uses
  ImagingJpeg, ImagingIO;
{$ENDIF}

resourcestring
  SErrorLoadingChunk = 'Error when reading %s chunk data. File may be corrupted.';

type
  { Chunk header.}
  TChunkHeader = packed record
    DataSize: LongWord;
    ChunkID: TChar4;
  end;

  { IHDR chunk format.}
  TIHDR = packed record
    Width: LongWord;              // Image width
    Height: LongWord;             // Image height
    BitDepth: Byte;               // Bits per pixel or bits per sample (for truecolor)
    ColorType: Byte;              // 0 = grayscale, 2 = truecolor, 3 = palette,
                                  // 4 = gray + alpha, 6 = truecolor + alpha
    Compression: Byte;            // Compression type:  0 = ZLib
    Filter: Byte;                 // Used precompress filter
    Interlacing: Byte;            // Used interlacing: 0 = no int, 1 = Adam7
  end;
  PIHDR = ^TIHDR;

  { MHDR chunk format.}
  TMHDR = packed record
    FrameWidth: LongWord;         // Frame width
    FrameHeight: LongWord;        // Frame height
    TicksPerSecond: LongWord;     // FPS of animation
    NominalLayerCount: LongWord;  // Number of layers in file
    NominalFrameCount: LongWord;  // Number of frames in file
    NominalPlayTime: LongWord;    // Play time of animation in ticks
    SimplicityProfile: LongWord;  // Defines which mMNG features are used in this file
  end;
  PMHDR = ^TMHDR;

  { JHDR chunk format.}
  TJHDR = packed record
    Width: LongWord;              // Image width
    Height: LongWord;             // Image height
    ColorType: Byte;              // 8 = grayscale (Y), 10 = color (YCbCr),
                                  // 12 = gray + alpha (Y-alpha), 14 = color + alpha (YCbCr-alpha)
    SampleDepth: Byte;            // 8, 12 or 20 (8 and 12 samples together) bit
    Compression: Byte;            // Compression type:  8 = Huffman coding
    Interlacing: Byte;            // 0 = single scan, 8 = progressive
    AlphaSampleDepth: Byte;       // 0, 1, 2, 4, 8, 16 if alpha compression is 0 (PNG)
                                  // 8 if alpha compression is 8 (JNG)
    AlphaCompression: Byte;       // 0 = PNG graysscale IDAT, 8 = grayscale 8-bit JPEG
    AlphaFilter: Byte;            // 0 = PNG filter or no filter (JPEG)
    AlphaInterlacing: Byte;       // 0 = non interlaced
  end;
  PJHDR = ^TJHDR;

const
  { PNG file identifier.}
  PNGSignature: TChar8 = #$89'PNG'#$0D#$0A#$1A#$0A;
  { MNG file identifier.}
  MNGSignature: TChar8 = #$8A'MNG'#$0D#$0A#$1A#$0A;
  { JNG file identifier.}
  JNGSignature: TChar8 = #$8B'JNG'#$0D#$0A#$1A#$0A;

  { Constants for chunk identifiers and signature identifiers.
    They are in big-endian format.}
  IHDRChunk: TChar4 = 'IHDR';
  IENDChunk: TChar4 = 'IEND';
  MHDRChunk: TChar4 = 'MHDR';
  MENDChunk: TChar4 = 'MEND';
  JHDRChunk: TChar4 = 'JHDR';
  IDATChunk: TChar4 = 'IDAT';
  JDATChunk: TChar4 = 'JDAT';
  JDAAChunk: TChar4 = 'JDAA';
  JSEPChunk: TChar4 = 'JSEP';
  PLTEChunk: TChar4 = 'PLTE';
  BACKChunk: TChar4 = 'BACK';
  DEFIChunk: TChar4 = 'DEFI';
  TERMChunk: TChar4 = 'TERM';
  tRNSChunk: TChar4 = 'tRNS';
  bKGDChunk: TChar4 = 'bKGD';
  gAMAChunk: TChar4 = 'gAMA';

  { Interlace start and offsets.}
  RowStart: array[0..6] of LongInt = (0, 0, 4, 0, 2, 0, 1);
  ColumnStart: array[0..6] of LongInt = (0, 4, 0, 2, 0, 1, 0);
  RowIncrement: array[0..6] of LongInt = (8, 8, 8, 4, 4, 2, 2);
  ColumnIncrement: array[0..6] of LongInt = (8, 8, 4, 4, 2, 2, 1);

type
  { Helper class that holds information about MNG frame in PNG or JNG format.}
  TFrameInfo = class(TObject)
  public
    IsJNG: Boolean;
    IHDR: TIHDR;
    JHDR: TJHDR;
    Palette: PPalette24;
    PaletteEntries: LongInt;
    Transparency: Pointer;
    TransparencySize: LongInt;
    Background: Pointer;
    BackgroundSize: LongInt;
    IDATMemory: TMemoryStream;
    JDATMemory: TMemoryStream;
    JDAAMemory: TMemoryStream;
    constructor Create;
    destructor Destroy; override;
  end;

  { Defines type of Network Graphics file.}
  TNGFileType = (ngPNG, ngMNG, ngJNG);

  TNGFileHandler = class(TObject)
  public
    FileType: TNGFileType;
    Frames: array of TFrameInfo;
    MHDR: TMHDR;
    procedure Clear;
    function GetLastFrame: TFrameInfo;
    function AddFrameInfo: TFrameInfo;
  end;

  { Network Graphics file parser and frame converter.}
  TNGFileLoader = class(TNGFileHandler)
  public
    function LoadFile(Handle: TImagingHandle): Boolean;
    procedure LoadImageFromPNGFrame(const IHDR: TIHDR; IDATStream: TMemoryStream; var Image: TImageData);
{$IFDEF LINK_JNG}
    procedure LoadImageFromJNGFrame(const JHDR: TJHDR; IDATStream, JDATStream, JDAAStream: TMemoryStream; var Image: TImageData);
{$ENDIF}
    procedure ApplyFrameSettings(Frame: TFrameInfo; var Image: TImageData);
  end;

  TNGFileSaver = class(TNGFileHandler)
  public
    PreFilter: LongInt;
    CompressLevel: LongInt;
    LossyAlpha: Boolean;
    Quality: LongInt;
    Progressive: Boolean;
    function SaveFile(Handle: TImagingHandle): Boolean;
    procedure AddFrame(const Image: TImageData; IsJNG: Boolean);
    procedure StoreImageToPNGFrame(const IHDR: TIHDR; Bits: Pointer; FmtInfo: TImageFormatInfo; IDATStream: TMemoryStream);
{$IFDEF LINK_JNG}
    procedure StoreImageToJNGFrame(const JHDR: TJHDR; const Image: TImageData; IDATStream, JDATStream, JDAAStream: TMemoryStream);
{$ENDIF}
    procedure SetFileOptions(FileFormat: TNetworkGraphicsFileFormat);
  end;

{$IFDEF LINK_JNG}
  TCustomIOJpegFileFormat = class(TJpegFileFormat)
  protected
    FCustomIO: TIOFunctions;
    procedure SetJpegIO(const JpegIO: TIOFunctions); override;
    procedure SetCustomIO(const CustomIO: TIOFunctions);
  end;
{$ENDIF}  

var
  NGFileLoader: TNGFileLoader = nil;
  NGFileSaver: TNGFileSaver = nil;

{ Helper routines }

function PaethPredictor(A, B, C: LongInt): LongInt; {$IFDEF USE_INLINE}inline;{$ENDIF}
var
  P, PA, PB, PC: LongInt;
begin
  P := A + B - C;
  PA := Abs(P - A);
  PB := Abs(P - B);
  PC := Abs(P - C);
  if (PA <= PB) and (PA <= PC) then
    Result := A
  else
    if PB <= PC then
      Result := B
    else
      Result := C;
end;

procedure SwapRGB(Line: PByte; Width, SampleDepth, BytesPerPixel: LongInt);
var
  I: LongInt;
  Tmp: Word;
begin
  case SampleDepth of
    8:
      for I := 0 to Width - 1 do
      with PColor24Rec(Line)^ do
      begin
        Tmp := R;
        R := B;
        B := Tmp;
        Inc(Line, BytesPerPixel);
      end;
    16:
      for I := 0 to Width - 1 do
      with PColor48Rec(Line)^ do
      begin
        Tmp := R;
        R := B;
        B := Tmp;
        Inc(Line, BytesPerPixel);
      end;
    end;
 end;

const
  { Helper constants for 1/2/4 bit to 8 bit conversions.}
  Mask1: array[0..7] of Byte = ($80, $40, $20, $10, $08, $04, $02, $01);
  Shift1: array[0..7] of Byte = (7, 6, 5, 4, 3, 2, 1, 0);
  Mask2: array[0..3] of Byte = ($C0, $30, $0C, $03);
  Shift2: array[0..3] of Byte = (6, 4, 2, 0);
  Mask4: array[0..1] of Byte = ($F0, $0F);
  Shift4: array[0..1] of Byte = (4, 0);

function Get1BitPixel(Line: PByteArray; X: LongInt): Byte;
begin
  Result := (Line[X shr 3] and Mask1[X and 7]) shr
    Shift1[X and 7];
end;

function Get2BitPixel(Line: PByteArray; X: LongInt): Byte;
begin
  Result := (Line[X shr 2] and Mask2[X and 3]) shr
    Shift2[X and 3];
end;

function Get4BitPixel(Line: PByteArray; X: LongInt): Byte;
begin
  Result := (Line[X shr 1] and Mask4[X and 1]) shr
    Shift4[X and 1];
end;

{$IFDEF LINK_JNG}

{ TCustomIOJpegFileFormat class implementation }

procedure TCustomIOJpegFileFormat.SetCustomIO(const CustomIO: TIOFunctions);
begin
  FCustomIO := CustomIO;
end;

procedure TCustomIOJpegFileFormat.SetJpegIO(const JpegIO: TIOFunctions);
begin
  inherited SetJpegIO(FCustomIO);
end;

{$ENDIF}

{ TFrameInfo class implementation }

constructor TFrameInfo.Create;
begin
  IDATMemory := TMemoryStream.Create;
  JDATMemory := TMemoryStream.Create;
  JDAAMemory := TMemoryStream.Create;
end;

destructor TFrameInfo.Destroy;
begin
  FreeMem(Palette);
  FreeMem(Transparency);
  FreeMem(Background);
  IDATMemory.Free;
  JDATMemory.Free;
  JDAAMemory.Free;
  inherited Destroy;
end;

{ TNGFileHandler class implementation}

procedure TNGFileHandler.Clear;
var
  I: LongInt;
begin
  for I := 0 to Length(Frames) - 1 do
    Frames[I].Free;
  SetLength(Frames, 0);
end;

function TNGFileHandler.GetLastFrame: TFrameInfo;
var
  Len: LongInt;
begin
  Len := Length(Frames);
  if Len > 0 then
    Result := Frames[Len - 1]
  else
    Result := nil;
end;

function TNGFileHandler.AddFrameInfo: TFrameInfo;
var
  Len: LongInt;
begin
  Len := Length(Frames);
  SetLength(Frames, Len + 1);
  Result := TFrameInfo.Create;
  Frames[Len] := Result;
end;

{ TNGFileLoader class implementation}

function TNGFileLoader.LoadFile(Handle: TImagingHandle): Boolean;
var
  Sig: TChar8;
  Chunk: TChunkHeader;
  ChunkData: Pointer;
  ChunkCrc: LongWord;

  procedure ReadChunk;
  begin
    GetIO.Read(Handle, @Chunk, SizeOf(Chunk));
    Chunk.DataSize := SwapEndianLongWord(Chunk.DataSize);
  end;

  procedure ReadChunkData;
  var
    ReadBytes: LongWord;
  begin
    FreeMemNil(ChunkData);
    GetMem(ChunkData, Chunk.DataSize);
    ReadBytes := GetIO.Read(Handle, ChunkData, Chunk.DataSize);
    GetIO.Read(Handle, @ChunkCrc, SizeOf(ChunkCrc));

    if ReadBytes <> Chunk.DataSize then
      raise EImagingError.CreateFmt(SErrorLoadingChunk, [string(Chunk.ChunkID)]);
  end;

  procedure SkipChunkData;
  begin
    GetIO.Seek(Handle, Chunk.DataSize + SizeOf(ChunkCrc), smFromCurrent);
  end;

  procedure StartNewPNGImage;
  var
    Frame: TFrameInfo;
  begin
    ReadChunkData;
    Frame := AddFrameInfo;
    Frame.IsJNG := False;
    Frame.IHDR := PIHDR(ChunkData)^;
  end;

  procedure StartNewJNGImage;
  var
    Frame: TFrameInfo;
  begin
    ReadChunkData;
    Frame := AddFrameInfo;
    Frame.IsJNG := True;
    Frame.JHDR := PJHDR(ChunkData)^;
  end;

  procedure AppendIDAT;
  begin
    ReadChunkData;
    // Append current IDAT chunk to storage stream
    GetLastFrame.IDATMemory.Write(ChunkData^, Chunk.DataSize);
  end;

  procedure AppendJDAT;
  begin
    ReadChunkData;
    // Append current JDAT chunk to storage stream
    GetLastFrame.JDATMemory.Write(ChunkData^, Chunk.DataSize);
  end;

  procedure AppendJDAA;
  begin
    ReadChunkData;
    // Append current JDAA chunk to storage stream
    GetLastFrame.JDAAMemory.Write(ChunkData^, Chunk.DataSize);
  end;

  procedure LoadPLTE;
  begin
    ReadChunkData;
    if GetLastFrame.Palette = nil then
    begin
      GetMem(GetLastFrame.Palette, Chunk.DataSize);
      Move(ChunkData^, GetLastFrame.Palette^, Chunk.DataSize);
      GetLastFrame.PaletteEntries := Chunk.DataSize div 3;
    end;
  end;

  procedure LoadtRNS;
  begin
    ReadChunkData;
    if GetLastFrame.Transparency = nil then
    begin
      GetMem(GetLastFrame.Transparency, Chunk.DataSize);
      Move(ChunkData^, GetLastFrame.Transparency^, Chunk.DataSize);
      GetLastFrame.TransparencySize := Chunk.DataSize;
    end;
  end;

  procedure LoadbKGD;
  begin
    ReadChunkData;
    if GetLastFrame.Background = nil then
    begin
      GetMem(GetLastFrame.Background, Chunk.DataSize);
      Move(ChunkData^, GetLastFrame.Background^, Chunk.DataSize);
      GetLastFrame.BackgroundSize := Chunk.DataSize;
    end;
  end;

begin
  Result := False;
  Clear;
  ChunkData := nil;
  with GetIO do
  try
    Read(Handle, @Sig, SizeOf(Sig));
    // Set file type according to the signature
    if Sig = PNGSignature then FileType := ngPNG
    else if Sig = MNGSignature then FileType := ngMNG
    else if Sig = JNGSignature then FileType := ngJNG
    else Exit;

    if FileType = ngMNG then
    begin
      // Store MNG header if present
      ReadChunk;
      ReadChunkData;
      MHDR := PMHDR(ChunkData)^;
      SwapEndianLongWord(@MHDR, SizeOf(MHDR) div SizeOf(LongWord));
    end
    else
      FillChar(MHDR, SizeOf(MHDR), 0);

    // Read chunks until ending chunk or EOF is reached
    repeat
      ReadChunk;
      if Chunk.ChunkID = IHDRChunk then StartNewPNGImage
      else if Chunk.ChunkID = JHDRChunk then StartNewJNGImage
      else if Chunk.ChunkID = IDATChunk then AppendIDAT
      else if Chunk.ChunkID = JDATChunk then AppendJDAT
      else if Chunk.ChunkID = JDAAChunk then AppendJDAA
      else if Chunk.ChunkID = PLTEChunk then LoadPLTE
      else if Chunk.ChunkID = tRNSChunk then LoadtRNS
      else if Chunk.ChunkID = bKGDChunk then LoadbKGD
      else SkipChunkData;
    until Eof(Handle) or (Chunk.ChunkID = MENDChunk) or
      ((FileType <> ngMNG) and (Chunk.ChunkID = IENDChunk));

    Result := True;  
  finally
    FreeMemNil(ChunkData);
  end;
end;

procedure TNGFileLoader.LoadImageFromPNGFrame(const IHDR: TIHDR;
  IDATStream: TMemoryStream; var Image: TImageData);
type
  TGetPixelFunc = function(Line: PByteArray; X: LongInt): Byte;
var
  LineBuffer: array[Boolean] of PByteArray;
  ActLine: Boolean;
  Data, TotalBuffer, ZeroLine, PrevLine: Pointer;
  BitCount, TotalSize, TotalPos, BytesPerPixel, I, Pass,
  SrcDataSize, BytesPerLine, InterlaceLineBytes, InterlaceWidth: LongInt;

  procedure DecodeAdam7;
  const
    BitTable: array[1..8] of LongInt = ($1, $3, 0, $F, 0, 0, 0, $FF);
    StartBit: array[1..8] of LongInt = (7, 6, 0, 4, 0, 0, 0, 0);
  var
    Src, Dst, Dst2: PByte;
    CurBit, Col: LongInt;
  begin
    Src := @LineBuffer[ActLine][1];
    Col := ColumnStart[Pass];
    with Image do
      case BitCount of
        1, 2, 4:
          begin
            Dst := @PByteArray(Data)[I * BytesPerLine];
            repeat
              CurBit := StartBit[BitCount];
              repeat
                Dst2 := @PByteArray(Dst)[(BitCount * Col) shr 3];
                Dst2^ := Dst2^ or ((Src^ shr CurBit) and BitTable[BitCount])
                  shl (StartBit[BitCount] - (Col * BitCount mod 8));
                Inc(Col, ColumnIncrement[Pass]);
                Dec(CurBit, BitCount);
              until CurBit < 0;
              Inc(Src);
            until Col >= Width;
          end;
        else
        begin
          Dst := @PByteArray(Data)[I * BytesPerLine + Col * BytesPerPixel];
          repeat
            CopyPixel(Src, Dst, BytesPerPixel);
            Inc(Dst, BytesPerPixel);
            Inc(Src, BytesPerPixel);
            Inc(Dst, ColumnIncrement[Pass] * BytesPerPixel - BytesPerPixel);
            Inc(Col, ColumnIncrement[Pass]);
          until Col >= Width;
        end;
      end;
  end;

  procedure FilterScanline(Filter: Byte; BytesPerPixel: LongInt; Line, PrevLine, Target: PByteArray;
    BytesPerLine: LongInt);
  var
    I: LongInt;
  begin
    case Filter of
      0:
        begin
          // No filter
          Move(Line^, Target^, BytesPerLine);
        end;
      1:
        begin
          // Sub filter
          Move(Line^, Target^, BytesPerPixel);
          for I := BytesPerPixel to BytesPerLine - 1 do
            Target[I] := (Line[I] + Target[I - BytesPerPixel]) and $FF;
        end;
      2:
        begin
          // Up filter
          for I := 0 to BytesPerLine - 1 do
            Target[I] := (Line[I] + PrevLine[I]) and $FF;
        end;
      3:
        begin
          // Average filter
          for I := 0 to BytesPerPixel - 1 do
            Target[I] := (Line[I] + PrevLine[I] shr 1) and $FF;
          for I := BytesPerPixel to BytesPerLine - 1 do
            Target[I] := (Line[I] + (Target[I - BytesPerPixel] + PrevLine[I]) shr 1) and $FF;
        end;
      4:
        begin
          // Paeth filter
          for I := 0 to BytesPerPixel - 1 do
            Target[I] := (Line[I] + PaethPredictor(0, PrevLine[I], 0)) and $FF;
          for I := BytesPerPixel to BytesPerLine - 1 do
            Target[I] := (Line[I] + PaethPredictor(Target[I - BytesPerPixel], PrevLine[I], PrevLine[I - BytesPerPixel])) and $FF;
        end;
    end;
  end;

  procedure Convert124To8(DataIn: Pointer; DataOut: Pointer; Width, Height,
    WidthBytes: LongInt; Indexed: Boolean);
  var
    X, Y, Mul: LongInt;
    GetPixel: TGetPixelFunc;
  begin
    GetPixel := Get1BitPixel;
    Mul := 255;
    case IHDR.BitDepth of
      2:
        begin
          Mul := 85;
          GetPixel := Get2BitPixel;
        end;
      4:
        begin
          Mul := 17;
          GetPixel := Get4BitPixel;
        end;
    end;
    if Indexed then Mul := 1;

    for Y := 0 to Height - 1 do
      for X := 0 to Width - 1 do
        PByteArray(DataOut)[Y * Width + X] :=
          GetPixel(@PByteArray(DataIn)[Y * WidthBytes], X) * Mul;
  end;

  procedure TransformLOCOToRGB(Data: PByte; NumPixels, BytesPerPixel: LongInt);
  var
    I: LongInt;
  begin
    for I := 0 to NumPixels - 1 do
    begin
      if IHDR.BitDepth = 8 then
      begin
        PColor32Rec(Data).R := Byte(PColor32Rec(Data).R + PColor32Rec(Data).G);
        PColor32Rec(Data).B := Byte(PColor32Rec(Data).B + PColor32Rec(Data).G);
      end
      else
      begin
        PColor64Rec(Data).R := Word(PColor64Rec(Data).R + PColor64Rec(Data).G);
        PColor64Rec(Data).B := Word(PColor64Rec(Data).B + PColor64Rec(Data).G);
      end;
      Inc(Data, BytesPerPixel);
    end;
  end;

begin
  Image.Width := SwapEndianLongWord(IHDR.Width);
  Image.Height := SwapEndianLongWord(IHDR.Height);
  Image.Format := ifUnknown;

  case IHDR.ColorType of
    0:
      begin
        // Gray scale image
        case IHDR.BitDepth of
          1, 2, 4, 8: Image.Format := ifGray8;
          16: Image.Format := ifGray16;
        end;
        BitCount := IHDR.BitDepth;
      end;
    2:
      begin
        // RGB image
        case IHDR.BitDepth of
          8:  Image.Format := ifR8G8B8;
          16: Image.Format := ifR16G16B16;
        end;
        BitCount := IHDR.BitDepth * 3;
      end;
    3:
      begin
        // Indexed image
        case IHDR.BitDepth of
          1, 2, 4, 8: Image.Format := ifIndex8;
        end;
        BitCount := IHDR.BitDepth;
      end;
    4:
      begin
        // Grayscale + alpha image
        case IHDR.BitDepth of
          8: Image.Format := ifA8Gray8;
          16: Image.Format := ifA16Gray16;
        end;
        BitCount := IHDR.BitDepth * 2;
      end;
    6:
      begin
        // ARGB image
        case IHDR.BitDepth of
          8: Image.Format := ifA8R8G8B8;
          16: Image.Format := ifA16R16G16B16;
        end;
        BitCount := IHDR.BitDepth * 4;
      end;
  end;

  // Start decoding
  LineBuffer[True] := nil;
  LineBuffer[False] := nil;
  TotalBuffer := nil;
  ZeroLine := nil;
  BytesPerPixel := (BitCount + 7) div 8;
  ActLine := True;
  with Image do
  try
    BytesPerLine := (Width * BitCount + 7) div 8;
    SrcDataSize := Height * BytesPerLine;
    GetMem(Data, SrcDataSize);
    FillChar(Data^, SrcDataSize, 0);
    GetMem(ZeroLine, BytesPerLine);
    FillChar(ZeroLine^, BytesPerLine, 0);

    if IHDR.Interlacing = 1 then
    begin
      // Decode interlaced images
      TotalPos := 0;
      DecompressBuf(IDATStream.Memory, IDATStream.Size, 0,
        Pointer(TotalBuffer), TotalSize);
      GetMem(LineBuffer[True], BytesPerLine + 1);
      GetMem(LineBuffer[False], BytesPerLine + 1);
      for Pass := 0 to 6 do
      begin
        // Prepare next interlace run
        if Width <= ColumnStart[Pass] then
          Continue;
        InterlaceWidth := (Width + ColumnIncrement[Pass] - 1 -
          ColumnStart[Pass]) div ColumnIncrement[Pass];
        InterlaceLineBytes := (InterlaceWidth * BitCount + 7) shr 3;
        I := RowStart[Pass];
        FillChar(LineBuffer[True][0], BytesPerLine + 1, 0);
        FillChar(LineBuffer[False][0], BytesPerLine + 1, 0);
        while I < Height do
        begin
          // Copy line from decompressed data to working buffer
          Move(PByteArray(TotalBuffer)[TotalPos],
            LineBuffer[ActLine][0], InterlaceLineBytes + 1);
          Inc(TotalPos, InterlaceLineBytes + 1);
          // Swap red and blue channels if necessary
          if (IHDR.ColorType in [2, 6]) then
            SwapRGB(@LineBuffer[ActLine][1], InterlaceWidth, IHDR.BitDepth, BytesPerPixel);
          // Reverse-filter current scanline
          FilterScanline(LineBuffer[ActLine][0], BytesPerPixel,
            @LineBuffer[ActLine][1], @LineBuffer[not ActLine][1],
            @LineBuffer[ActLine][1], InterlaceLineBytes);
          // Decode Adam7 interlacing
          DecodeAdam7;
          ActLine := not ActLine;
          // Continue with next row in interlaced order
          Inc(I, RowIncrement[Pass]);
        end;
      end;
    end
    else
    begin
      // Decode non-interlaced images
      PrevLine := ZeroLine;
      DecompressBuf(IDATStream.Memory, IDATStream.Size, SrcDataSize + Height,
        Pointer(TotalBuffer), TotalSize);
      for I := 0 to Height - 1 do
      begin
        // Swap red and blue channels if necessary
        if IHDR.ColorType in [2, 6] then
          SwapRGB(@PByteArray(TotalBuffer)[I * (BytesPerLine + 1) + 1], Width,
           IHDR.BitDepth, BytesPerPixel);
        // reverse-filter current scanline
        FilterScanline(PByteArray(TotalBuffer)[I * (BytesPerLine + 1)],
          BytesPerPixel, @PByteArray(TotalBuffer)[I * (BytesPerLine + 1) + 1],
          PrevLine, @PByteArray(Data)[I * BytesPerLine], BytesPerLine);
        PrevLine := @PByteArray(Data)[I * BytesPerLine];
      end;
    end;

    Size := Width * Height * BytesPerPixel;

    if Size <> SrcDataSize then
    begin
      // If source data size is different from size of image in assigned
      // format we must convert it (it is in 1/2/4 bit count)
      GetMem(Bits, Size);
      case IHDR.ColorType of
        0: Convert124To8(Data, Bits, Width, Height, BytesPerLine, False);
        3: Convert124To8(Data, Bits, Width, Height, BytesPerLine, True);
      end;
      FreeMem(Data);
    end
    else
    begin
      // If source data size is the same as size of
      // image Bits in assigned format we simply copy pointer reference
      Bits := Data;
    end;

    // LOCO transformation was used too (only for color types 2 and 6)
    if (IHDR.Filter = 64) and (IHDR.ColorType in [2, 6]) then
      TransformLOCOToRGB(Bits, Width * Height, BytesPerPixel);

    // Images with 16 bit channels must be swapped because of PNG's big endianity
    if IHDR.BitDepth = 16 then
      SwapEndianWord(Bits, Width * Height * BytesPerPixel div SizeOf(Word));
  finally
    FreeMem(LineBuffer[True]);
    FreeMem(LineBuffer[False]);
    FreeMem(TotalBuffer);
    FreeMem(ZeroLine);
  end;
end;

{$IFDEF LINK_JNG}

procedure TNGFileLoader.LoadImageFromJNGFrame(const JHDR: TJHDR; IDATStream,
  JDATStream, JDAAStream: TMemoryStream; var Image: TImageData);
var
  AlphaImage: TImageData;
  FakeIHDR: TIHDR;
  FmtInfo: TImageFormatInfo;
  I: LongInt;
  AlphaPtr: PByte;
  GrayPtr: PWordRec;
  ColorPtr: PColor32Rec;

  procedure LoadJpegFromStream(Stream: TStream; var DestImage: TImageData);
  var
    JpegFormat: TCustomIOJpegFileFormat;
    Handle: TImagingHandle;
    DynImages: TDynImageDataArray;
  begin
    if JHDR.SampleDepth <> 12 then
    begin
      JpegFormat := TCustomIOJpegFileFormat.Create;
      JpegFormat.SetCustomIO(StreamIO);
      Stream.Position := 0;
      Handle := StreamIO.OpenRead(Pointer(Stream));
      try
        JpegFormat.LoadData(Handle, DynImages, True);
        DestImage := DynImages[0];
      finally
        StreamIO.Close(Handle);
        JpegFormat.Free;
        SetLength(DynImages, 0);
      end;
    end
    else
      NewImage(JHDR.Width, JHDR.Height, ifR8G8B8, DestImage);
  end;

begin
  LoadJpegFromStream(JDATStream, Image);

  // If present separate alpha channel is processed
  if (JHDR.ColorType in [12, 14]) and (Image.Format in [ifGray8, ifR8G8B8]) then
  begin
    InitImage(AlphaImage);
    if JHDR.AlphaCompression = 0 then
    begin
      // Alpha channel is PNG compressed
      FakeIHDR.Width := JHDR.Width;
      FakeIHDR.Height := JHDR.Height;
      FakeIHDR.ColorType := 0;
      FakeIHDR.BitDepth := JHDR.AlphaSampleDepth;
      FakeIHDR.Filter := JHDR.AlphaFilter;
      FakeIHDR.Interlacing := JHDR.AlphaInterlacing;

      LoadImageFromPNGFrame(FakeIHDR, IDATStream, AlphaImage);
    end
    else
    begin
      // Alpha channel is JPEG compressed
      LoadJpegFromStream(JDAAStream, AlphaImage);
    end;

    // Check if alpha channel is the same size as image
    if (Image.Width <> AlphaImage.Width) and (Image.Height <> AlphaImage.Height) then
      ResizeImage(AlphaImage, Image.Width, Image.Height, rfNearest);

    // Check alpha channels data format
    GetImageFormatInfo(AlphaImage.Format, FmtInfo);
    if (FmtInfo.BytesPerPixel > 1) or (not FmtInfo.HasGrayChannel) then
      ConvertImage(AlphaImage, ifGray8);

    // Convert image to fromat with alpha channel
    if Image.Format = ifGray8 then
      ConvertImage(Image, ifA8Gray8)
    else
      ConvertImage(Image, ifA8R8G8B8);

    // Combine alpha channel with image
    AlphaPtr := AlphaImage.Bits;
    if Image.Format = ifA8Gray8 then
    begin
      GrayPtr := Image.Bits;
      for I := 0 to Image.Width * Image.Height - 1 do
      begin
        GrayPtr.High := AlphaPtr^;
        Inc(GrayPtr);
        Inc(AlphaPtr);
      end;
    end
    else
    begin
      ColorPtr := Image.Bits;
      for I := 0 to Image.Width * Image.Height - 1 do
      begin
        ColorPtr.A := AlphaPtr^;
        Inc(ColorPtr);
        Inc(AlphaPtr);
      end;
    end;

    FreeImage(AlphaImage);
  end;
end;

{$ENDIF}

procedure TNGFileLoader.ApplyFrameSettings(Frame: TFrameInfo; var Image: TImageData);
var
  FmtInfo: TImageFormatInfo;
  BackGroundColor: TColor64Rec;
  ColorKey: TColor64Rec;
  Alphas: PByteArray;
  AlphasSize: LongInt;
  IsColorKeyPresent: Boolean;
  IsBackGroundPresent: Boolean;
  IsColorFormat: Boolean;

  procedure ConverttRNS;
  begin
    if FmtInfo.IsIndexed then
    begin
      if Alphas = nil then
      begin
        GetMem(Alphas, Frame.TransparencySize);
        Move(Frame.Transparency^, Alphas^, Frame.TransparencySize);
        AlphasSize := Frame.TransparencySize;
      end;
    end
    else
    if not FmtInfo.HasAlphaChannel then
    begin
      FillChar(ColorKey, SizeOf(ColorKey), 0);
      Move(Frame.Transparency^, ColorKey, Min(Frame.TransparencySize, SizeOf(ColorKey)));
      if IsColorFormat then
        SwapValues(ColorKey.R, ColorKey.B);
      SwapEndianWord(@ColorKey, 3);
      // 1/2/4 bit images were converted to 8 bit so we must convert color key too
      if (not Frame.IsJNG) and (Frame.IHDR.ColorType in [0, 4]) then
        case Frame.IHDR.BitDepth of
          1: ColorKey.B := Word(ColorKey.B * 255);
          2: ColorKey.B := Word(ColorKey.B * 85);
          4: ColorKey.B := Word(ColorKey.B * 17);
        end;
      IsColorKeyPresent := True;
    end;
  end;

  procedure ConvertbKGD;
  begin
    FillChar(BackGroundColor, SizeOf(BackGroundColor), 0);
    Move(Frame.Background^, BackGroundColor, Min(Frame.BackgroundSize,
      SizeOf(BackGroundColor)));
    if IsColorFormat then
      SwapValues(BackGroundColor.R, BackGroundColor.B);
    SwapEndianWord(@BackGroundColor, 3);
    // 1/2/4 bit images were converted to 8 bit so we must convert back color too
    if (not Frame.IsJNG) and (Frame.IHDR.ColorType in [0, 4]) then
      case Frame.IHDR.BitDepth of
        1: BackGroundColor.B := Word(BackGroundColor.B * 255);
        2: BackGroundColor.B := Word(BackGroundColor.B * 85);
        4: BackGroundColor.B := Word(BackGroundColor.B * 17);
      end;
    IsBackGroundPresent := True;
  end;

  procedure ReconstructPalette;
  var
    I: LongInt;
  begin
    with Image do
    begin
      GetMem(Palette, FmtInfo.PaletteEntries * SizeOf(TColor32Rec));
      FillChar(Palette^, FmtInfo.PaletteEntries * SizeOf(TColor32Rec), $FF);
      // if RGB palette was loaded from file then use it
      if Frame.Palette <> nil then
        for I := 0 to Min(Frame.PaletteEntries, FmtInfo.PaletteEntries) - 1 do
        with Palette[I] do
        begin
          R := Frame.Palette[I].B;
          G := Frame.Palette[I].G;
          B := Frame.Palette[I].R;
        end;
      // if palette alphas were loaded from file then use them
      if Alphas <> nil then
        for I := 0 to Min(AlphasSize, FmtInfo.PaletteEntries) - 1 do
          Palette[I].A := Alphas[I];
    end;
  end;

  procedure ApplyColorKey;
  var
    DestFmt: TImageFormat;
    OldPixel, NewPixel: Pointer;
  begin
    case Image.Format of
      ifGray8: DestFmt := ifA8Gray8;
      ifGray16: DestFmt := ifA16Gray16;
      ifR8G8B8: DestFmt := ifA8R8G8B8;
      ifR16G16B16: DestFmt := ifA16R16G16B16;
    else
      DestFmt := ifUnknown;
    end;
    if DestFmt <> ifUnknown then
    begin
      if not IsBackGroundPresent then
        BackGroundColor := ColorKey;
      ConvertImage(Image, DestFmt);
      OldPixel := @ColorKey;
      NewPixel := @BackGroundColor;
      // Now back color and color key must be converted to image's data format, looks ugly
      case Image.Format of
        ifA8Gray8:
          begin
            TColor32Rec(TInt64Rec(ColorKey).Low).B := Byte(ColorKey.B);
            TColor32Rec(TInt64Rec(ColorKey).Low).G := $FF;
            TColor32Rec(TInt64Rec(BackGroundColor).Low).B := Byte(BackGroundColor.B);
          end;
        ifA16Gray16:
          begin
            ColorKey.G := $FFFF;
          end;
        ifA8R8G8B8:
          begin
            TColor32Rec(TInt64Rec(ColorKey).Low).R := Byte(ColorKey.R);
            TColor32Rec(TInt64Rec(ColorKey).Low).G := Byte(ColorKey.G);
            TColor32Rec(TInt64Rec(ColorKey).Low).B := Byte(ColorKey.B);
            TColor32Rec(TInt64Rec(ColorKey).Low).A := $FF;
            TColor32Rec(TInt64Rec(BackGroundColor).Low).R := Byte(BackGroundColor.R);
            TColor32Rec(TInt64Rec(BackGroundColor).Low).G := Byte(BackGroundColor.G);
            TColor32Rec(TInt64Rec(BackGroundColor).Low).B := Byte(BackGroundColor.B);
          end;
        ifA16R16G16B16:
          begin
            ColorKey.A := $FFFF;
          end;
      end;
      ReplaceColor(Image, 0, 0, Image.Width, Image.Height, OldPixel, NewPixel);
    end;
  end;

begin
  Alphas := nil;
  IsColorKeyPresent := False;
  IsBackGroundPresent := False;
  GetImageFormatInfo(Image.Format, FmtInfo);

  IsColorFormat := (Frame.IsJNG and (Frame.JHDR.ColorType in [10, 14])) or
    (not Frame.IsJNG and (Frame.IHDR.ColorType in [2, 6]));

  // convert some chunk data to useful format
  if Frame.Transparency <> nil then
    ConverttRNS;
  if Frame.Background <> nil then
    ConvertbKGD;

  // Build palette for indexed images
  if FmtInfo.IsIndexed then
    ReconstructPalette;

  // Apply color keying
  if IsColorKeyPresent and not FmtInfo.HasAlphaChannel then
    ApplyColorKey;

  FreeMemNil(Alphas);
end;

{ TNGFileSaver class implementation }

procedure TNGFileSaver.StoreImageToPNGFrame(const IHDR: TIHDR; Bits: Pointer;
  FmtInfo: TImageFormatInfo; IDATStream: TMemoryStream);
var
  TotalBuffer, CompBuffer, ZeroLine, PrevLine: Pointer;
  FilterLines: array[0..4] of PByteArray;
  TotalSize, CompSize, I, BytesPerLine, BytesPerPixel: LongInt;
  Filter: Byte;
  Adaptive: Boolean;

  procedure FilterScanline(Filter: Byte; BytesPerPixel: LongInt; Line, PrevLine, Target: PByteArray);
  var
    I: LongInt;
  begin
    case Filter of
      0:
        begin
          // No filter
          Move(Line^, Target^, BytesPerLine);
        end;
      1:
        begin
          // Sub filter
          Move(Line^, Target^, BytesPerPixel);
          for I := BytesPerPixel to BytesPerLine - 1 do
            Target[I] := (Line[I] - Line[I - BytesPerPixel]) and $FF;
        end;
      2:
        begin
          // Up filter
          for I := 0 to BytesPerLine - 1 do
            Target[I] := (Line[I] - PrevLine[I]) and $FF;
        end;
      3:
        begin
          // Average filter
          for I := 0 to BytesPerPixel - 1 do
            Target[I] := (Line[I] - PrevLine[I] shr 1) and $FF;
          for I := BytesPerPixel to BytesPerLine - 1 do
            Target[I] := (Line[I] - (Line[I - BytesPerPixel] + PrevLine[I]) shr 1) and $FF;
        end;
      4:
        begin
          // Paeth filter
          for I := 0 to BytesPerPixel - 1 do
            Target[I] := (Line[I] - PaethPredictor(0, PrevLine[I], 0)) and $FF;
          for I := BytesPerPixel to BytesPerLine - 1 do
            Target[I] := (Line[I] - PaethPredictor(Line[I - BytesPerPixel], PrevLine[I], PrevLine[I - BytesPerPixel])) and $FF;
        end;
    end;
  end;

  procedure AdaptiveFilter(var Filter: Byte; BytesPerPixel: LongInt; Line, PrevLine, Target: PByteArray);
  var
    I, J, BestTest: LongInt;
    Sums: array[0..4] of LongInt;
  begin
    // Compute the output scanline using all five filters,
    // and select the filter that gives the smallest sum of
    // absolute values of outputs
    FillChar(Sums, SizeOf(Sums), 0);
    BestTest := MaxInt;
    for I := 0 to 4 do
    begin
      FilterScanline(I, BytesPerPixel, Line, PrevLine, FilterLines[I]);
      for J := 0 to BytesPerLine - 1 do
        Sums[I] := Sums[I] + Abs(ShortInt(FilterLines[I][J]));
      if Sums[I] < BestTest then
      begin
        Filter := I;
        BestTest := Sums[I];
      end;
    end;
    Move(FilterLines[Filter]^, Target^, BytesPerLine);
  end;
  
begin
  // Select precompression filter and compression level
  Adaptive := False;
  Filter := 0;
  case PreFilter of
    6:
      if not ((IHDR.BitDepth < 8) or (IHDR.ColorType = 3))
        then Adaptive := True;
    0..4: Filter := PreFilter;
  else
    if IHDR.ColorType in [2, 6] then
      Filter := 4
  end;
  // Prepare data for compression
  CompBuffer := nil;
  FillChar(FilterLines, SizeOf(FilterLines), 0);
  BytesPerPixel := FmtInfo.BytesPerPixel;
  BytesPerLine := LongInt(IHDR.Width) * BytesPerPixel;
  TotalSize := (BytesPerLine + 1) * LongInt(IHDR.Height);
  GetMem(TotalBuffer, TotalSize);
  GetMem(ZeroLine, BytesPerLine);
  FillChar(ZeroLine^, BytesPerLine, 0);
  if Adaptive then
    for I := 0 to 4 do
      GetMem(FilterLines[I], BytesPerLine);
  PrevLine := ZeroLine;
  try
    // Process next scanlines
    for I := 0 to IHDR.Height - 1 do
    begin
      // Filter scanline
      if Adaptive then
        AdaptiveFilter(Filter, BytesPerPixel, @PByteArray(Bits)[I * BytesPerLine],
          PrevLine, @PByteArray(TotalBuffer)[I * (BytesPerLine + 1) + 1])
      else
        FilterScanline(Filter, BytesPerPixel, @PByteArray(Bits)[I * BytesPerLine],
          PrevLine, @PByteArray(TotalBuffer)[I * (BytesPerLine + 1) + 1]);
      PrevLine := @PByteArray(Bits)[I * BytesPerLine];
      // Swap red and blue if necessary
      if (IHDR.ColorType in [2, 6]) and (not FmtInfo.IsRBSwapped) then
        SwapRGB(@PByteArray(TotalBuffer)[I * (BytesPerLine + 1) + 1],
          IHDR.Width, IHDR.BitDepth, FmtInfo.BytesPerPixel);
      // Images with 16 bit channels must be swapped because of PNG's big endianess
      if IHDR.BitDepth = 16 then
        SwapEndianWord(@PByteArray(TotalBuffer)[I * (BytesPerLine + 1) + 1],
          BytesPerLine div SizeOf(Word));
      // Set filter used for this scanline
      PByteArray(TotalBuffer)[I * (BytesPerLine + 1)] := Filter;
    end;
    // Compress IDAT data
    CompressBuf(TotalBuffer, TotalSize, CompBuffer, CompSize, CompressLevel);
    // Write IDAT data to stream
    IDATStream.WriteBuffer(CompBuffer^, CompSize);
  finally
    FreeMem(TotalBuffer);
    FreeMem(CompBuffer);
    FreeMem(ZeroLine);
    if Adaptive then
      for I := 0 to 4 do
        FreeMem(FilterLines[I]);
  end;
end;

{$IFDEF LINK_JNG}

procedure TNGFileSaver.StoreImageToJNGFrame(const JHDR: TJHDR;
  const Image: TImageData; IDATStream, JDATStream,
  JDAAStream: TMemoryStream);
var
  ColorImage, AlphaImage: TImageData;
  FmtInfo: TImageFormatInfo;
  AlphaPtr: PByte;
  GrayPtr: PWordRec;
  ColorPtr: PColor32Rec;
  I: LongInt;
  FakeIHDR: TIHDR;

  procedure SaveJpegToStream(Stream: TStream; const Image: TImageData);
  var
    JpegFormat: TCustomIOJpegFileFormat;
    Handle: TImagingHandle;
    DynImages: TDynImageDataArray;
  begin
    JpegFormat := TCustomIOJpegFileFormat.Create;
    JpegFormat.SetCustomIO(StreamIO);
    // Only JDAT stream can be saved progressive
    if Stream = JDATStream then
      JpegFormat.FProgressive := Progressive
    else
      JpegFormat.FProgressive := False;
    JpegFormat.FQuality := Quality;
    SetLength(DynImages, 1);
    DynImages[0] := Image;
    Handle := StreamIO.OpenWrite(Pointer(Stream));
    try
      JpegFormat.SaveData(Handle, DynImages, 0);
    finally
      StreamIO.Close(Handle);
      SetLength(DynImages, 0);
      JpegFormat.Free;
    end;
  end;

begin
  GetImageFormatInfo(Image.Format, FmtInfo);

  if FmtInfo.HasAlphaChannel then
  begin
    // Create new image for alpha channel and color image without alpha
    CloneImage(Image, ColorImage);
    NewImage(Image.Width, Image.Height, ifGray8, AlphaImage);
    case Image.Format of
      ifA8Gray8:  ConvertImage(ColorImage, ifGray8);
      ifA8R8G8B8: ConvertImage(ColorImage, ifR8G8B8);
    end;

    // Store source image's alpha to separate image
    AlphaPtr := AlphaImage.Bits;
    if Image.Format = ifA8Gray8 then
    begin
      GrayPtr := Image.Bits;
      for I := 0 to Image.Width * Image.Height - 1 do
      begin
        AlphaPtr^ := GrayPtr.High;
        Inc(GrayPtr);
        Inc(AlphaPtr);
      end;
    end
    else
    begin
      ColorPtr := Image.Bits;
      for I := 0 to Image.Width * Image.Height - 1 do
      begin
        AlphaPtr^ := ColorPtr.A;
        Inc(ColorPtr);
        Inc(AlphaPtr);
      end;
    end;

    // Write color image to stream as JPEG
    SaveJpegToStream(JDATStream, ColorImage);

    if LossyAlpha then
    begin
      // Write alpha image to stream as JPEG
      SaveJpegToStream(JDAAStream, AlphaImage);
    end
    else
    begin
      // Alpha channel is PNG compressed
      FakeIHDR.Width := JHDR.Width;
      FakeIHDR.Height := JHDR.Height;
      FakeIHDR.ColorType := 0;
      FakeIHDR.BitDepth := JHDR.AlphaSampleDepth;
      FakeIHDR.Filter := JHDR.AlphaFilter;
      FakeIHDR.Interlacing := JHDR.AlphaInterlacing;

      GetImageFormatInfo(AlphaImage.Format, FmtInfo);
      StoreImageToPNGFrame(FakeIHDR, AlphaImage.Bits, FmtInfo, IDATStream);
    end;

    FreeImage(ColorImage);
    FreeImage(AlphaImage);
  end
  else
  begin
    // Simply write JPEG to stream
    SaveJpegToStream(JDATStream, Image);
  end;
end;

{$ENDIF}

procedure TNGFileSaver.AddFrame(const Image: TImageData; IsJNG: Boolean);
var
  Frame: TFrameInfo;
  FmtInfo: TImageFormatInfo;

  procedure StorePalette;
  var
    Pal: PPalette24;
    Alphas: PByteArray;
    I, PalBytes: LongInt;
    AlphasDiffer: Boolean;
  begin
    // Fill and save RGB part of palette to PLTE chunk
    PalBytes := FmtInfo.PaletteEntries * SizeOf(TColor24Rec);
    GetMem(Pal, PalBytes);
    AlphasDiffer := False;
    for I := 0 to FmtInfo.PaletteEntries - 1 do
    begin
      Pal[I].B := Image.Palette[I].R;
      Pal[I].G := Image.Palette[I].G;
      Pal[I].R := Image.Palette[I].B;
      if Image.Palette[I].A < 255 then
        AlphasDiffer := True;
    end;
    Frame.Palette := Pal;
    Frame.PaletteEntries := FmtInfo.PaletteEntries;
    // Fill and save alpha part (if there are any alphas < 255) of palette to tRNS chunk
    if AlphasDiffer then
    begin
      PalBytes := FmtInfo.PaletteEntries * SizeOf(Byte);
      GetMem(Alphas, PalBytes);
      for I := 0 to FmtInfo.PaletteEntries - 1 do
        Alphas[I] := Image.Palette[I].A;
      Frame.Transparency := Alphas;
      Frame.TransparencySize := PalBytes;
    end;
  end;

begin
  // Add new frame
  Frame := AddFrameInfo;
  Frame.IsJNG := IsJNG;

  with Frame do
  begin
    GetImageFormatInfo(Image.Format, FmtInfo);

    if IsJNG then
    begin
{$IFDEF LINK_JNG}
      // Fill JNG header
      JHDR.Width := Image.Width;
      JHDR.Height := Image.Height;
      case Image.Format of
        ifGray8:    JHDR.ColorType := 8;
        ifR8G8B8:   JHDR.ColorType := 10;
        ifA8Gray8:  JHDR.ColorType := 12;
        ifA8R8G8B8: JHDR.ColorType := 14;
      end;
      JHDR.SampleDepth := 8; // 8-bit samples and quantization tables
      JHDR.Compression := 8; // Huffman coding
      JHDR.Interlacing := Iff(Progressive, 8, 0);
      JHDR.AlphaSampleDepth := Iff(FmtInfo.HasAlphaChannel, 8, 0);
      JHDR.AlphaCompression := Iff(LossyAlpha, 8, 0);
      JHDR.AlphaFilter := 0;
      JHDR.AlphaInterlacing := 0;

      StoreImageToJNGFrame(JHDR, Image, IDATMemory, JDATMemory, JDAAMemory);

      // Finally swap endian
      SwapEndianLongWord(@JHDR, 2);
{$ENDIF}
    end
    else
    begin
      // Fill PNG header
      IHDR.Width := Image.Width;
      IHDR.Height := Image.Height;
      IHDR.Compression := 0;
      IHDR.Filter := 0;
      IHDR.Interlacing := 0;
      IHDR.BitDepth := FmtInfo.BytesPerPixel * 8;

      // Select appropiate PNG color type and modify bitdepth
      if FmtInfo.HasGrayChannel then
      begin
        IHDR.ColorType := 0;
        if FmtInfo.HasAlphaChannel then
        begin
          IHDR.ColorType := 4;
          IHDR.BitDepth := IHDR.BitDepth div 2;
        end;
      end
      else
        if FmtInfo.IsIndexed then
          IHDR.ColorType := 3
        else
          if FmtInfo.HasAlphaChannel then
          begin
            IHDR.ColorType := 6;
            IHDR.BitDepth := IHDR.BitDepth div 4;
          end
          else
          begin
            IHDR.ColorType := 2;
            IHDR.BitDepth := IHDR.BitDepth div 3;
          end;

       // Compress PNG image and store it to stream
       StoreImageToPNGFrame(IHDR, Image.Bits, FmtInfo, IDATMemory);
       // Store palette if necesary
       if FmtInfo.IsIndexed then
         StorePalette;

       // Finally swap endian
       SwapEndianLongWord(@IHDR, 2);
    end;
  end;
end;

function TNGFileSaver.SaveFile(Handle: TImagingHandle): Boolean;
var
  I: LongInt;
  Chunk: TChunkHeader;

  function CalcChunkCrc(const ChunkHdr: TChunkHeader; Data: Pointer;
    Size: LongInt): LongWord;
  begin
    Result := $FFFFFFFF;
    CalcCrc32(Result, @ChunkHdr.ChunkID, SizeOf(ChunkHdr.ChunkID));
    CalcCrc32(Result, Data, Size);
    Result := SwapEndianLongWord(Result xor $FFFFFFFF);
  end;

  procedure WriteChunk(var Chunk: TChunkHeader; ChunkData: Pointer);
  var
    ChunkCrc: LongWord;
    SizeToWrite: LongInt;
  begin
    SizeToWrite := Chunk.DataSize;
    Chunk.DataSize := SwapEndianLongWord(Chunk.DataSize);
    ChunkCrc := CalcChunkCrc(Chunk, ChunkData, SizeToWrite);
    GetIO.Write(Handle, @Chunk, SizeOf(Chunk));
    if SizeToWrite <> 0 then
      GetIO.Write(Handle, ChunkData, SizeToWrite);
    GetIO.Write(Handle, @ChunkCrc, SizeOf(ChunkCrc));
  end;

begin
  Result := False;
  try
    case FileType of
      ngPNG: GetIO.Write(Handle, @PNGSignature, SizeOf(TChar8));
      ngMNG: GetIO.Write(Handle, @MNGSignature, SizeOf(TChar8));
      ngJNG: GetIO.Write(Handle, @JNGSignature, SizeOf(TChar8));
    end;

    if FileType = ngMNG then
    begin
      SwapEndianLongWord(@MHDR, SizeOf(MHDR) div SizeOf(LongWord));
      Chunk.DataSize := SizeOf(MHDR);
      Chunk.ChunkID := MHDRChunk;
      WriteChunk(Chunk, @MHDR);
    end;

    for I := 0 to Length(Frames) - 1 do
    with Frames[I] do
    begin
      if IsJNG then
      begin
        // Write JHDR chunk
        Chunk.DataSize := SizeOf(JHDR);
        Chunk.ChunkID := JHDRChunk;
        WriteChunk(Chunk, @JHDR);
        // Write JNG image data
        Chunk.DataSize := JDATMemory.Size;
        Chunk.ChunkID := JDATChunk;
        WriteChunk(Chunk, JDATMemory.Memory);
        // Write alpha channel if present
        if JHDR.AlphaSampleDepth > 0 then
        begin
          if JHDR.AlphaCompression = 0 then
          begin
            // ALpha is PNG compressed
            Chunk.DataSize := IDATMemory.Size;
            Chunk.ChunkID := IDATChunk;
            WriteChunk(Chunk, IDATMemory.Memory);
          end
          else
          begin
            // Alpha is JNG compressed
            Chunk.DataSize := JDAAMemory.Size;
            Chunk.ChunkID := JDAAChunk;
            WriteChunk(Chunk, JDAAMemory.Memory);
          end;
        end;
        // Write image end
        Chunk.DataSize := 0;
        Chunk.ChunkID := IENDChunk;
        WriteChunk(Chunk, nil);
      end
      else
      begin
        // Write IHDR chunk
        Chunk.DataSize := SizeOf(IHDR);
        Chunk.ChunkID := IHDRChunk;
        WriteChunk(Chunk, @IHDR);
        // Write PLTE chunk if data is present
        if Palette <> nil then
        begin
          Chunk.DataSize := PaletteEntries * SizeOf(TColor24Rec);
          Chunk.ChunkID := PLTEChunk;
          WriteChunk(Chunk, Palette);
        end;
        // Write tRNS chunk if data is present
        if Transparency <> nil then
        begin
          Chunk.DataSize := TransparencySize;
          Chunk.ChunkID := tRNSChunk;
          WriteChunk(Chunk, Transparency);
        end;
        // Write PNG image data
        Chunk.DataSize := IDATMemory.Size;
        Chunk.ChunkID := IDATChunk;
        WriteChunk(Chunk, IDATMemory.Memory);
        // Write image end
        Chunk.DataSize := 0;
        Chunk.ChunkID := IENDChunk;
        WriteChunk(Chunk, nil);
      end;
    end;

    if FileType = ngMNG then
    begin
      Chunk.DataSize := 0;
      Chunk.ChunkID := MENDChunk;
      WriteChunk(Chunk, nil);
    end;

  finally

  end;
end;

procedure TNGFileSaver.SetFileOptions(FileFormat: TNetworkGraphicsFileFormat);
begin
  PreFilter := FileFormat.FPreFilter;
  CompressLevel := FileFormat.FCompressLevel;
  LossyAlpha := FileFormat.FLossyAlpha;
  Quality := FileFormat.FQuality;
  Progressive := FileFormat.FProgressive;
end;

{ TNetworkGraphicsFileFormat class implementation }

constructor TNetworkGraphicsFileFormat.Create;
begin
  inherited Create;
  FCanLoad := True;
  FCanSave := True;
  FIsMultiImageFormat := False;

  FPreFilter := NGDefaultPreFilter;
  FCompressLevel := NGDefaultCompressLevel;
  FLossyAlpha := NGDefaultLossyAlpha;
  FLossyCompression := NGDefaultLossyCompression;
  FQuality := NGDefaultQuality;
  FProgressive := NGDefaultProgressive;
end;

function TNetworkGraphicsFileFormat.GetSupportedFormats: TImageFormats;
begin
  if FLossyCompression then
    Result := NGLossyFormats
  else
    Result := NGLosslessFormats;
end;

function TNetworkGraphicsFileFormat.MakeCompatible(const Image: TImageData;
  var Comp: TImageData): Boolean;
var
  Info: PImageFormatInfo;
  ConvFormat: TImageFormat;
begin
  if not inherited MakeCompatible(Image, Comp) then
  begin
    Info := GetFormatInfo(Comp.Format);
    if not FLossyCompression then
    begin
      // Convert formats for lossless compression
      if Info.HasGrayChannel then
      begin
        if Info.HasAlphaChannel then
        begin
          if Info.BytesPerPixel <= 2 then
            // Convert <= 16bit grayscale images with alpha to ifA8Gray8
            ConvFormat := ifA8Gray8
          else
            // Convert > 16bit grayscale images with alpha to ifA16Gray16
            ConvFormat := ifA16Gray16
        end
        else
          // Convert grayscale images without alpha to ifGray16
          ConvFormat := ifGray16;
      end
      else
        if Info.IsFloatingPoint then
          // Convert floating point images to 64 bit ARGB
          ConvFormat := ifA16B16G16R16
        else
          if Info.HasAlphaChannel or Info.IsSpecial then
            // Convert all other images with alpha or special images to A8R8G8B8
            ConvFormat := ifA8R8G8B8
          else
            // Convert images without alpha to R8G8B8
            ConvFormat := ifR8G8B8;
    end
    else
    begin
      // Convert formats for lossy compression
      if Info.HasGrayChannel then
        ConvFormat := IffFormat(Info.HasAlphaChannel, ifA8Gray8, ifGray8)
      else
        ConvFormat := IffFormat(Info.HasAlphaChannel, ifR8G8B8, ifA8R8G8B8)
    end;

    ConvertImage(Comp, ConvFormat);
  end;
  Result := Comp.Format in GetSupportedFormats;
end;

procedure TNetworkGraphicsFileFormat.SaveData(Handle: TImagingHandle;
  const Images: TDynImageDataArray; Index: Integer);
begin
  // Just check if save options has valid values
  if not (FPreFilter in [0..6]) then
    FPreFilter := NGDefaultPreFilter;
  if not (FCompressLevel in [0..9]) then
    FCompressLevel := NGDefaultCompressLevel;
  if not (FQuality in [1..100]) then
    FQuality := NGDefaultQuality;
end;

function TNetworkGraphicsFileFormat.TestFormat(Handle: TImagingHandle): Boolean;
var
  ReadCount: LongInt;
  Sig: TChar8;
begin
  Result := False;
  if Handle <> nil then
    with GetIO do
    begin
      FillChar(Sig, SizeOf(Sig), 0);
      ReadCount := Read(Handle, @Sig, SizeOf(Sig));
      Seek(Handle, -ReadCount, smFromCurrent);
      Result := (ReadCount = SizeOf(Sig)) and (Sig = FSignature);
    end;
end;

{ TPNGFileFormat class implementation }

constructor TPNGFileFormat.Create;
begin
  inherited Create;
  FName := SPNGFormatName;

  FSignature := PNGSignature;

  AddExtensions(SPNGExtensions);
  RegisterOption(ImagingPNGPreFilter, @FPreFilter);
  RegisterOption(ImagingPNGCompressLevel, @FCompressLevel);
end;

procedure TPNGFileFormat.LoadData(Handle: TImagingHandle;
  var Images: TDynImageDataArray; OnlyFirstLevel: Boolean);
begin
  try
    // Use NG file parser to load file
    if NGFileLoader.LoadFile(Handle) and (Length(NGFileLoader.Frames) > 0) then
    with NGFileLoader.Frames[0] do
    begin
      SetLength(Images, 1);
      // Build actual image bits
      if not IsJNG then
        NGFileLoader.LoadImageFromPNGFrame(IHDR, IDATMemory, Images[0]);
      // Build palette, aply color key or background
      NGFileLoader.ApplyFrameSettings(NGFileLoader.Frames[0], Images[0]);
    end;
  finally
    NGFileLoader.Clear;
  end;
end;

procedure TPNGFileFormat.SaveData(Handle: TImagingHandle;
  const Images: TDynImageDataArray; Index: LongInt);
var
  Len: LongInt;
  ImageToSave: TImageData;
begin
  inherited SaveData(Handle, Images, Index);
  Len := Length(Images);
  if Len = 0 then Exit;
  if (Index = MaxInt) or (Len = 1) then Index := 0;
  // Make image PNG compatible, store it in saver, and save it to file
  if MakeCompatible(Images[Index], ImageToSave) then
  with NGFileSaver do
  try
    FileType := ngPNG;
    SetFileOptions(Self);
    AddFrame(ImageToSave, False);
    SaveFile(Handle);
  finally
    // Clear NG saver and compatible image
    Clear;
    if Images[Index].Bits <> ImageToSave.Bits then
      FreeImage(ImageToSave);
  end;
end;

{$IFDEF LINK_MNG}

{ TMNGFileFormat class implementation }

constructor TMNGFileFormat.Create;
begin
  inherited Create;
  FName := SMNGFormatName;
  FIsMultiImageFormat := True;
  FSignature := MNGSignature;

  AddExtensions(SMNGExtensions);

  RegisterOption(ImagingMNGLossyCompression, @FLossyCompression);
  RegisterOption(ImagingMNGLossyAlpha, @FLossyAlpha);
  RegisterOption(ImagingMNGPreFilter, @FPreFilter);
  RegisterOption(ImagingMNGCompressLevel, @FCompressLevel);
  RegisterOption(ImagingMNGQuality, @FQuality);
  RegisterOption(ImagingMNGProgressive, @FProgressive);
end;

procedure TMNGFileFormat.LoadData(Handle: TImagingHandle;
  var Images: TDynImageDataArray; OnlyFirstLevel: Boolean);
var
  I, Len: LongInt;
begin
  try
    // Use NG file parser to load file
    if NGFileLoader.LoadFile(Handle) then
    begin
      Len := Length(NGFileLoader.Frames);
      if Len > 0 then
      begin
        SetLength(Images, Len);
        for I := 0 to Len - 1 do
        with NGFileLoader.Frames[I] do
        begin
          // Build actual image bits
          if IsJNG then
            NGFileLoader.LoadImageFromJNGFrame(JHDR, IDATMemory, JDATMemory, JDAAMemory, Images[I])
          else
            NGFileLoader.LoadImageFromPNGFrame(IHDR, IDATMemory, Images[I]);
          // Build palette, aply color key or background
          NGFileLoader.ApplyFrameSettings(NGFileLoader.Frames[I], Images[I]);
        end;
      end
      else
      begin
        // Some MNG files (with BASI-IEND streams) dont have actual pixel data
        SetLength(Images, 1);
        with NGFileLoader.MHDR do
          NewImage(FrameWidth, FrameWidth, ifDefault, Images[0]);
      end;
    end;
  finally
    NGFileLoader.Clear;
  end;
end;

procedure TMNGFileFormat.SaveData(Handle: TImagingHandle;
  const Images: TDynImageDataArray; Index: LongInt);
var
  I, FirstIdx, LastIdx, Len, LargestWidth, LargestHeight: LongInt;
  ImageToSave: TImageData;
begin
  inherited SaveData(Handle, Images, Index);
  Len := Length(Images);
  if Len = 0 then Exit;
  // Determine whether all frames or just one should be saved
  if (Index = MaxInt) or (Index > Len - 1) then
  begin
    FirstIdx := 0;
    LastIdx := Len - 1;
  end
  else
  begin
    FirstIdx := Index;
    LastIdx := Index;
  end;

  LargestWidth := 0;
  LargestHeight := 0;

  NGFileSaver.FileType := ngMNG;
  NGFileSaver.SetFileOptions(Self);

  with NGFileSaver do
  try
    // Store all frames to be saved frames file saver
    for I := FirstIdx to LastIdx do
    begin
      if MakeCompatible(Images[I], ImageToSave) then
      try
        // Add image as PNG or JNG frame
        AddFrame(ImageToSave, FLossyCompression);
        // Remember largest frame width and height
        LargestWidth := Iff(LargestWidth < ImageToSave.Width, ImageToSave.Width, LargestWidth);
        LargestHeight := Iff(LargestHeight < ImageToSave.Height, ImageToSave.Height, LargestHeight);
      finally
        if Images[I].Bits <> ImageToSave.Bits then
          FreeImage(ImageToSave);
      end;
    end;

    // Fill MNG header
    MHDR.FrameWidth := LargestWidth;
    MHDR.FrameHeight := LargestHeight;
    MHDR.TicksPerSecond := 0;
    MHDR.NominalLayerCount := 0;
    MHDR.NominalFrameCount := Length(Frames);
    MHDR.NominalPlayTime := 0;
    MHDR.SimplicityProfile := 473; // 111011001 binary, defines MNG-VLC with transparency and JNG support

    // Finally save MNG file
    SaveFile(Handle);
  finally
    Clear;
  end;
end;

{$ENDIF}

{$IFDEF LINK_JNG}

{ TJNGFileFormat class implementation }

constructor TJNGFileFormat.Create;
begin
  inherited Create;
  FName := SJNGFormatName;
  FSignature := JNGSignature;

  FLossyCompression := True;
  
  AddExtensions(SJNGExtensions);

  RegisterOption(ImagingJNGLossyAlpha, @FLossyAlpha);
  RegisterOption(ImagingJNGAlphaPreFilter, @FPreFilter);
  RegisterOption(ImagingJNGAlphaCompressLevel, @FCompressLevel);
  RegisterOption(ImagingJNGQuality, @FQuality);
  RegisterOption(ImagingJNGProgressive, @FProgressive);
end;

procedure TJNGFileFormat.LoadData(Handle: TImagingHandle;
  var Images: TDynImageDataArray; OnlyFirstLevel: Boolean);
begin
  try
    // Use NG file parser to load file
    if NGFileLoader.LoadFile(Handle) and (Length(NGFileLoader.Frames) > 0) then
    with NGFileLoader.Frames[0] do
    begin
      SetLength(Images, 1);
      // Build actual image bits
      if IsJNG then
        NGFileLoader.LoadImageFromJNGFrame(JHDR, IDATMemory, JDATMemory, JDAAMemory, Images[0]);
      // Build palette, aply color key or background
      NGFileLoader.ApplyFrameSettings(NGFileLoader.Frames[0], Images[0]);
    end;
  finally
    NGFileLoader.Clear;
  end;
end;

procedure TJNGFileFormat.SaveData(Handle: TImagingHandle;
  const Images: TDynImageDataArray; Index: LongInt);
var
  Len: LongInt;
  ImageToSave: TImageData;
begin
  inherited SaveData(Handle, Images, Index);
  Len := Length(Images);
  if Len = 0 then Exit;
  if (Index = MaxInt) or (Len = 1) then Index := 0;
  // Make image JNG compatible, store it in saver, and save it to file
  if MakeCompatible(Images[Index], ImageToSave) then
  with NGFileSaver do
  try
    FileType := ngJNG;
    SetFileOptions(Self);
    AddFrame(ImageToSave, True);
    SaveFile(Handle);
  finally
    // Clear NG saver and compatible image
    Clear;
    if Images[Index].Bits <> ImageToSave.Bits then
      FreeImage(ImageToSave);
  end;
end;

{$ENDIF}

initialization
  NGFileLoader := TNGFileLoader.Create;
  NGFileSaver := TNGFileSaver.Create;
  RegisterImageFileFormat(TPNGFileFormat);
{$IFDEF LINK_MNG}
  RegisterImageFileFormat(TMNGFileFormat);
{$ENDIF}
{$IFDEF LINK_JNG}
  RegisterImageFileFormat(TJNGFileFormat);
{$ENDIF}  
finalization
  FreeAndNil(NGFileLoader);
  FreeAndNil(NGFileSaver);

{
  File Notes:

  -- TODOS ----------------------------------------------------
    - nothing now

  -- 0.17 Changes/Bug Fixes -----------------------------------
    - MNG and JNG support added, PNG support redesigned to support NG file handlers
    - added classes for working with NG file formats
    - stuff from old ImagingPng unit added and that unit was deleted
    - unit created and initial stuff added
    
  -- 0.15 Changes/Bug Fixes -----------------------------------
    - when saving indexed images save alpha to tRNS?
    - added some defines and ifdefs to dzlib unit to allow choosing
      impaszlib, fpc's paszlib, zlibex or other zlib implementation
    - added colorkeying support
    - fixed 16bit channel image handling - pixels were not swapped
    - fixed arithmetic overflow (in paeth filter) in FPC
    - data of unknown chunks are skipped and not needlesly loaded

  -- 0.13 Changes/Bug Fixes -----------------------------------
    - adaptive filtering added to PNG saving
    - TPNGFileFormat class added
}

end.