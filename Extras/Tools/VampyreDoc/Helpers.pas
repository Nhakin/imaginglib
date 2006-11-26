unit Helpers;

{$INCLUDE ImagingOptions.inc}

interface

uses
  SysUtils, Classes, ImagingUtility, DemoUtils, DOM, XMLRead, XMLWrite;

const
  sXTOCRoot = 'toc';
  sXTOCList = 'itemlist';
  sXTOCItem = 'item';
  sXName = 'name';
  sXURL = 'url';
  sXTOCFile = 'toc';
  sXTitle = 'title';
  sXRootFile = 'root';
  sXOutputFile = 'output';
  sXXslDir = 'xsldir';
  sXRefDir = 'refdir';
  SXProducer = 'producer';
  sXLinkTargetURL = 'url';
  sXLinkTargetAnchor = 'anchor';
  sXRef = 'ref';
  sXAnchorDelim = '#';
  sXTemplate = '<?xml version="1.0" encoding="utf-8"?>' + sLineBreak +
    '<?xml-stylesheet type="text/xsl" href="%s/doc2html.xsl"?>' + sLineBreak +
    '<doc>' + sLineBreak +
    '  <title>Template</title>' + sLineBreak +
    '  <chapter>' + sLineBreak +
    '    <title>Template</title>' + sLineBreak +
    '    <par>This file was autogenerated by VampyreDoc</par>' + sLineBreak +
    '  </chapter>' + sLineBreak +
    '</doc>';

  sURLDelim = '/';
  sXSLLink = 'link';
  sXSLHref = 'href';
  sXSLSrc = 'src';
  sCSSExt = 'css';
  sCSSLink = 'url';
  sCSSLinkBStart = '(';
  sCSSLinkBEnd = ')';

type
  { Base class for objects based on elements of XML files.}
  TXMLItem = class(TObject)
  private
    FElement: TDOMElement;
    procedure ParseElement; virtual; abstract;
    function FindElement(const NodeName: string; Parent: TDOMElement;
      var Elem: TDOMElement): Boolean;
  public
    constructor Create(AElement: TDOMElement);
    property Element: TDOMElement read FElement;
  end;

  TDocProject = class;

  { This class represents table of contents with items stored in tree.
    Use your projects toc xml file as input to constructor.}
  TContentItem = class(TXMLItem)
  private
    FChildren: TList;
    FURL: string;
    FName: string;
    FProject: TDocProject;
    function GetChild(Index: Integer): TContentItem;
    function GetChildCount: LongInt;
    procedure ParseElement; override;
  public
    constructor Create(AElement: TDOMElement; AProject: TDocProject);
    destructor Destroy; override;

    property Child[Index: LongInt]: TContentItem read GetChild; default;
    property ChildCount: LongInt read GetChildCount;
    property URL: string read FURL;
    property Name: string read FName;
  end;

  { This class represents whole VampyreDoc project loaded from
    .vdocproj xml file. It contains table of contents loaded
    from toc xml file.}
  TDocProject = class(TXMLItem)
  private
    FProjectFile: string;
    FTitle: string;
    FContentsFile: string;
    FOutputFile: string;
    FRootFile: string;
    FXslDir: string;
    FRefDir: string;
    FContents: TContentItem;
    FFiles: TStrings;
    procedure ParseElement; override;
  public
    constructor Create(AElement: TDOMElement; const AProjectFile: string);
    destructor Destroy; override;

    property ProjectFile: string read FProjectFile;
    property Title: string read FTitle;
    property ContentsFile: string read FContentsFile;
    property OutputFile: string read FOutputFile;
    property RootFile: string read FRootFile;
    property XslDir: string read FXslDir;
    property RefDir: string read FRefDir;
    property Contents: TContentItem read FContents;
  end;

  { Base class for output documentation producers. They take
    project and output directory and transform xml based VampyreDoc
    files to another formats like HTML or CHM.}
  TDocProducer = class(TObject)
  protected
    FName: string;
  public
    procedure Process(Project: TDocProject; const OutDir: string); virtual; abstract;
    property Name: string read FName;
  end;

  TCustomConverter = function(const S, Context: string): string;

  TLinker = class(TObject)
  private
    FDoc: TXMLDocument;
    FResultPath: string;
    FProject: TDocProject;
    FFileName: string;
    FIntendedOutput: string;
    FExternalRefs: TStringList;
    function ResolveExternalLink(const Link: string; const BasePath: string = ''): string;
    procedure CheckElement(Elem: TDOMElement); virtual; abstract;
    function ConvertLink(const Link, Context: string): string; virtual; abstract;
  public
    constructor Create;
    destructor Destroy; override;

    function CheckDocument(const FileName: string; Project: TDocProject): Boolean; virtual;
    procedure SaveResult(const FileName: string);
    procedure DeleteResult;

    property Doc: TXMLDocument read FDoc; 
    property References: TStringList read FExternalRefs;
    property IntendedOutput: string read FIntendedOutput write FIntendedOutput;
  end;

  { This class is used by doc producers to convert all links to external
    files in VampyreDoc xml files to format compatible with producer's
    output format.}
  TLinkChecker = class(TLinker)
  private
    FStripDir: Boolean;
    FExtension: string;
    FNewPathDelim: string;
    FDestDir: string;
    FCustomConverter: TCustomConverter;
    FRefFiles: TStringList;
    procedure CheckElement(Elem: TDOMElement); override;
    function ConvertLink(const Link, Context: string): string; override;
    procedure ResolveReferenceLink(Elem: TDOMElement);
  public
    function CheckDocument(const FileName: string; Project: TDocProject): Boolean; override;
    property StripDir: Boolean read FStripDir write FStripDir;
    property Extension: string read FExtension write FExtension;
    property NewPathDelim: string read FNewPathDelim write FNewPathDelim;
    property DestDir: string read FDestDir write FDestDir;
    property CustomConverter: TCustomConverter read FCustomConverter write
      FCustomConverter;
  end;

  { This class checks XSL stylesheet used to transform documents and
    if there are any links (href and src) to existing files these
    files are copied to IntendedOutput's directory.
    If link refers to CSS stylesheet, this sheet is parsed and
    all references to external files (like background-image: url())
    are processed - files are copied to output dir and urls are updated
    (Note: your original CSS styles are not changed! Only styles
    copied to output dir are parsed).)}
  TXSLLinker = class(TLinker)
  private
    procedure CheckElement(Elem: TDOMElement); override;
    function ConvertLink(const Link, Context: string): string; override;
    procedure ParseCSSFile(const DestCSS, SourceCSS: string);
  public
  end;

{ Runs given command line and waits until process ends.
  Returns True if process was successfuly executed.}
function RunCmdLine(const CmdLine: string): Boolean;
{ Transforms InDoc XML document to OutDoc using StyleSheet XSL file.
  You must have Instant Saxon installed and in OS's search path
  in order to work in Windows.}
procedure TransformDoc(const InDoc, OutDoc, StyleSheet: string);
{ Returns list filled with filenames of all files contained in project.}
procedure ProjectToStrings(Project: TDocProject; List: TStrings);
{ Creates files refered by project's toc file but which do not exist yet.}
procedure GenerateTOCTemplates(Project: TDocProject);
{ Outputs message. Uses Write if compiled as console app or nothing if else.}
procedure Msg(const S: string);

implementation

{$IFDEF MSWINDOWS}
uses
  Windows;
{$ENDIF}

function RunCmdLine(const CmdLine: string): Boolean;
{$IFDEF MSWINDOWS}
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
begin
  Result := False;
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  with StartupInfo do
  begin
    cb := SizeOf(StartupInfo);
    dwFlags := STARTF_USESHOWWINDOW;
    wShowWindow := SW_SHOW;
  end;

  if CreateProcess(nil, PChar(CmdLine), nil, nil,
    False, NORMAL_PRIORITY_CLASS, nil, nil, StartupInfo, ProcessInfo) then
  begin
    repeat
    until WaitForSingleObject(ProcessInfo.hProcess, 1) = WAIT_OBJECT_0;
    CloseHandle(ProcessInfo.hProcess);
    CloseHandle(ProcessInfo.hThread);
    Result := True;
  end
  else
    Msg('Cannot run command line: ' + CmdLine);
end;
{$ELSE}
begin
  Msg('RunCmdLine is not implemented for this platform yet.');
end;
{$ENDIF}

procedure TransformDoc(const InDoc, OutDoc, StyleSheet: string);
var
  CmdLine: string;
begin
  CmdLine := 'saxon -o ' + OutDoc + ' ' + InDoc + ' ' + StyleSheet;
  if not RunCmdLine(CmdLine) then
    raise Exception.Create('SAXON cannot be executed.');
end;

procedure ProjectToStrings(Project: TDocProject; List: TStrings);

  procedure AddItem(Item: TContentItem);
  var
    I: LongInt;
  begin
    List.Add(Item.URL);
    for I := 0 to Item.ChildCount - 1 do
      AddItem(Item[I]);
  end;

begin
  List.Clear;
  AddItem(Project.FContents);
  List.Add(Project.FContentsFile);
end;

procedure GenerateTOCTemplates(Project: TDocProject);
var
  I: LongInt;
  Stream: TFileStream;
  S, XslPath: string;
begin
  for I := 0 to Project.FFiles.Count - 1 do
    if not FileExists(Project.FFiles[I]) then
    try
      ForceDirectories(ExtractFileDir(Project.FFiles[I]));
      Stream := TFileStream.Create(Project.FFiles[I], fmCreate);
      XslPath := SwapPathDelims(
        ExtractRelativePath(Project.FFiles[I], Project.FXslDir), sURLDelim);
      S := Format(sXTemplate, [XslPath]);
      Stream.Write(S[1], Length(S));
      Stream.Free;
    except
    end;
end;

procedure Msg(const S: string);
begin
  if System.IsConsole then
    WriteLn(S);
end;

{ TXMLItem }

constructor TXMLItem.Create(AElement: TDOMElement);
begin
  inherited Create;
  FElement := AElement;
  ParseElement;
end;

function TXMLItem.FindElement(const NodeName: string; Parent: TDOMElement;
  var Elem: TDOMElement): Boolean;
var
  I: LongInt;
begin
  Elem := TDOMElement(Parent.FindNode(NodeName));
  Result := Elem <> nil;
  if (not Result) and (Parent.ChildNodes.Count > 0) then
    for I := 0 to Parent.ChildNodes.Count - 1 do
    begin
      Result := FindElement(NodeName, TDOMElement(Parent.ChildNodes.Item[I]), Elem);
      if Result then
        Break;
    end;
end;

{ TContentItem }

constructor TContentItem.Create(AElement: TDOMElement; AProject: TDocProject);
begin
  FProject := AProject;
  inherited Create(AElement);
end;

destructor TContentItem.Destroy;
var
  I: LongInt;
begin
  for I := 0 to FChildren.Count - 1 do
    TContentItem(FChildren[I]).Free;
  FChildren.Free;
  inherited Destroy;
end;

function TContentItem.GetChild(Index: LongInt): TContentItem;
begin
  Result := TContentItem(FChildren[Index]);
end;

function TContentItem.GetChildCount: LongInt;
begin
  Result := FChildren.Count;
end;

procedure TContentItem.ParseElement;
var
  I: LongInt;
  Elem: TDOMElement;
begin
  FChildren := TList.Create;

  // if given element is root of toc file we find first valid
  // toc item element
  if SameText(FElement.NodeName, sXTOCRoot) then
    if not FindElement(sXTOCItem, FElement, Elem) then
      Exit
    else
     FElement := Elem;

  // we assign attributes of toc item element to properties
  FName := FElement.GetAttribute(sXName);
  FURL := SwapPathDelims(FElement.GetAttribute(sXURL));
  FURL := ExpandFileTo(FURL, ExtractFileDir(FProject.ProjectFile));

  // if toc item contains toc itemlist and this list has some items
  // we add these items to child list of this content item
  if (FElement.FirstChild <> nil) and
    (FElement.FirstChild.ChildNodes.Count > 0) and
    (FElement.NodeType = ELEMENT_NODE) then
    for I := 0 to FElement.FirstChild.GetChildNodes.Count - 1 do
      if Element.FirstChild.ChildNodes.Item[I].NodeType = ELEMENT_NODE then
      FChildren.Add(TContentItem.Create(
        TDOMElement(FElement.FirstChild.ChildNodes.Item[I]), FProject));
end;

{ TDocProject }

constructor TDocProject.Create(AElement: TDOMElement; const AProjectFile: string);
begin
  FProjectFile := AProjectFile;
  inherited Create(AElement);
end;

destructor TDocProject.Destroy;
begin
  FFiles.Free;
  FContents.Free;
  inherited Destroy;
end;

procedure TDocProject.ParseElement;
var
  ContDoc: TXMLDocument;
begin
  FTitle := FElement.FindNode(sXTitle).FirstChild.NodeValue;
  FContentsFile := SwapPathDelims(FElement.FindNode(sXTOCFile).FirstChild.NodeValue);
  FOutputFile := SwapPathDelims(FElement.FindNode(sXOutputFile).FirstChild.NodeValue);
  FRootFile := SwapPathDelims(FElement.FindNode(sXRootFile).FirstChild.NodeValue);
  FXslDir := SwapPathDelims(FElement.FindNode(sXXslDir).FirstChild.NodeValue);
  FRefDir := SwapPathDelims(FElement.FindNode(sXRefDir).FirstChild.NodeValue);

  FContentsFile := ExpandFileTo(FContentsFile, ExtractFileDir(FProjectFile));
  FXslDir := ExpandFileTo(FXslDir, ExtractFileDir(FProjectFile));
  FRefDir := ExpandFileTo(FRefDir, ExtractFileDir(FProjectFile));

  XMLRead.ReadXMLFile(ContDoc, FContentsFile);
  FContents := TContentItem.Create(ContDoc.DocumentElement, Self);
  ContDoc.Free;

  FFiles := TStringList.Create;
  ProjectToStrings(Self, FFiles);
end;

{ TLinker }

constructor TLinker.Create;
begin
  inherited Create;
  FExternalRefs := TStringList.Create;
  FExternalRefs.Sorted := True;
end;

destructor TLinker.Destroy;
begin
  FExternalRefs.Free;
  FDoc.Free;
  inherited Destroy;
end;

function TLinker.CheckDocument(const FileName: string;
  Project: TDocProject): Boolean;
begin
  Result := False;
  FreeAndNil(FDoc);
  FProject := Project;
  FFileName := FileName;
  FExternalRefs.Clear;
  if FileExists(FFileName) then
  try
    XMLRead.ReadXMLFile(FDoc, FFileName);
    FDoc.Encoding := 'utf-8';
    CheckElement(FDoc.DocumentElement);
    Result := True;
  except
  end;
end;

procedure TLinker.SaveResult(const FileName: string);
begin
  if fDoc <> nil then
  begin
    FResultPath := FileName;
    XMLWrite.WriteXMLFile(FDoc, FResultPath);
  end;
end;

procedure TLinker.DeleteResult;
begin
  FreeAndNil(FDoc);
  SysUtils.DeleteFile(FResultPath);
end;

function TLinker.ResolveExternalLink(const Link: string; const BasePath: string): string;
var
  FullPath, Base: string;
begin
  Base := BasePath;
  if Base = '' then
    Base := FFileName;
  Result := Link;
  FullPath := SwapPathDelims(Result);
  FullPath := ExpandFileTo(FullPath, ExtractFileDir(Base));
  // if this link targets existing external file we copy this
  // file to directory where intended transformed doc will be output
  // and change link's target to only file name with no dir
  if FileExists(FullPath) then
  begin
    CopyFile(PChar(FullPath), PChar(ExtractFileDir(FIntendedOutput) +
      PathDelim + ExtractFileName(FullPath)), False);
    Result := ExtractFileName(FullPath);
    FExternalRefs.Add(Result);
  end;
end;

{ TLinkChecker }

function TLinkChecker.CheckDocument(const FileName: string;
  Project: TDocProject): Boolean;
var
  I: LongInt;
begin
  FRefFiles := TStringList.Create;
  BuildFileList(Project.FRefDir + PathDelim + '*', faAnyFile, FRefFiles, [flFullNames, flRecursive]);
  Result := inherited CheckDocument(FileName, Project);
  FRefFiles.Free;
end;

procedure TLinkChecker.ResolveReferenceLink(Elem: TDOMElement);
var
  I: LongInt;
  Name, Ref, Link: string;
begin
  for I := 0 to FRefFiles.Count - 1 do
  begin
    Name := LowerCase(ExtractFileName(FRefFiles[I]));
    Ref := LowerCase(Elem.FirstChild.NodeValue);
    if Pos(Ref, Name) = 1 then
    begin
      Link := ExtractRelativePath(FIntendedOutput, FRefFiles[I]);
      Link := SwapPathDelims(Link, FNewPathDelim);
      Elem.SetAttribute(sXURL, Link);
      Break;
    end;
  end;
end;

procedure TLinkChecker.CheckElement(Elem: TDOMElement);
var
  I: LongInt;
  Link: string;

  procedure ConvertAttrib(const Name: string);
  var
    Anchor: string;
  begin
    Link := Elem.GetAttribute(Name);
    if Link <> '' then
    begin
      // we must handle links to anchors
      I := Pos(sXAnchorDelim, Link);
      if I > 0 then
      begin
        Anchor := Copy(Link, I, MaxInt);
        Delete(Link, I, MaxInt);
      end;
      Link := ConvertLink(Link, Name);
      if I > 0 then
        Link := Link + Anchor;
      Elem.SetAttribute(Name, Link);
    end;
  end;

begin
  if Elem.NodeType = ELEMENT_NODE then
  begin
    // convert links in url, anchor and ref attributes of
    // tags like link, listlink, ...
    ConvertAttrib(sXLinkTargetURL);
    ConvertAttrib(sXLinkTargetAnchor);

    // this is only for mail project file and
    // converts root and contents file names (needed by xsl stylesheet
    // when transforming project file)
    if (SameText(Elem.NodeName, sXTOCFile) or
      SameText(Elem.NodeName, sXRef) or
      SameText(Elem.NodeName, sXRootFile)) and
      ((Elem.FirstChild <> nil) and (Elem.FirstChild.NodeValue <> '')) then
    begin
      Link := Elem.FirstChild.NodeValue;
      if not SameText(Elem.NodeName, sXRef) then
        Elem.FirstChild.NodeValue := ConvertLink(Link, Elem.NodeName)
      else
        ResolveReferenceLink(Elem);
    end;
  end;
  for I := 0 to Elem.ChildNodes.Count - 1 do
    CheckElement(TDOMElement(Elem.ChildNodes.Item[I]));
end;

function TLinkChecker.ConvertLink(const Link, Context: string): string;

 function FileIsInTOC(const Link: string): Boolean;
 var
   I: LongInt;
   S: string;
 begin
   Result := False;
   S := ExtractFileName(SwapPathDelims(Link));
   for I := 0 to FProject.FFiles.Count - 1 do
     if SameText(ExtractFileName(FProject.FFiles[I]), S) then
     begin
       Result := True;
       Break;
     end;
 end;

begin
  Result := Link;
  if Result <> '' then
  begin
    if FileIsInTOC(Result) then
    begin
      // for all files in toc (original XML documents)
      // we can strip original directory, add new directory,
      // change file extension and swap path delimiters
      Result := SwapPathDelims(Result);
      if FStripDir then
        Result := ExtractFileName(Result);
      if FDestDir <> '' then
        Result := FDestDir + FNewPathDelim + Result;
      Result := ChangeFileExt(Result, '.' + FExtension);
      Result := SwapPathDelims(Result, FNewPathDelim);
    end
    else
      Result := ResolveExternalLink(Result);
  end;
  if Assigned(FCustomConverter) then
    Result := FCustomConverter(Result, Context);
end;


{ TCSSLinker }

procedure TXSLLinker.CheckElement(Elem: TDOMElement);
var
  I: LongInt;
  Link: string;

  procedure ConvertAttrib(const Name: string);
  begin
    Link := Elem.GetAttribute(Name);
    if Link <> '' then
    begin
      Link := ConvertLink(Link, Name);
      Elem.SetAttribute(Name, Link);
    end;
  end;

begin
  if Elem.NodeType = ELEMENT_NODE then
  begin
    ConvertAttrib(sXSLHref);
    ConvertAttrib(sXSLSrc);
  end;
  for I := 0 to Elem.ChildNodes.Count - 1 do
    CheckElement(TDOMElement(Elem.ChildNodes.Item[I]));
end;

function TXSLLinker.ConvertLink(const Link, Context: string): string;
begin
  Result := ResolveExternalLink(Link);
  if SameText(GetFileExt(Result), sCSSExt) then
    ParseCSSFile(Result, Link);
end;

procedure TXSLLinker.ParseCSSFile(const DestCSS, SourceCSS: string);
var
  FullPath, FullSourcePath, TheCSS, WriteCSS, Path: string;
  Stream: TFileStream;
  PStart, PEnd, P: PChar;
  Len: LongInt;
  I: LongInt;
begin
  // first we get path to the destination CSS file which was copied
  // do IntendedOutput's dir by previously called ResolveExternalLink
  FullPath := SwapPathDelims(DestCSS);
  FullPath := ExtractFileDir(FIntendedOutput) + PathDelim +
    ExtractFileName(FullPath);
  // now we get path to the source CSS file
  FullSourcePath := SwapPathDelims(SourceCSS);
  FullSourcePath := ExpandFileTo(FullSourcePath, ExtractFileDir(FFileName));
  // if both files exist we process them
  if FileExists(FullPath) and FileExists(FullSourcePath) then
  begin
    // we read CSS file to memory string
    Stream := TFileStream.Create(FullPath, fmOpenRead);
    SetString(TheCSS, nil, Stream.Size);
    Stream.Read(TheCSS[1], Length(TheCSS));
    Stream.Free;
    WriteCSS := TheCSS;
    // now we are looking for references to external files in CSS
    // (some-property: url(someurl);)
    PStart := StrPos(PChar(TheCSS), sCSSLink);
    while PStart <> nil do
    begin
      PStart := StrPos(PStart, sCSSLinkBStart);
      PEnd := StrPos(PStart, sCSSLinkBEnd);
      if PEnd = nil then
        Break;
      Inc(PStart, Length(sCSSLinkBStart));
      Len := LongInt(PEnd) - LongInt(PStart);
      GetMem(P, Len + 1);
      StrLCopy(P, PStart, Len);
      Path := StrPas(P);
      for I := 1 to Length(Path) do
        if (Path[I] = '''') or (Path[I] = '"') then
          Path[I] := ' ';
      Path := Trim(Path);
      // now we have parameter of CSS's url() function in Path
      // we must resolve this external link but we must
      // use path to the source CSS in resolving (we are handling
      // paths relative to source CSS)
      Path := ResolveExternalLink(Path, FullSourcePath);
      // replace old path with new path in dest CSS
      WriteCSS := StringReplace(WriteCSS, StrPas(P), Path, [rfReplaceAll]);
      FreeMem(P);
      PStart := StrPos(PEnd, sCSSLink);
    end;
    // write dest CSS to the file
    Stream := TFileStream.Create(FullPath, fmCreate);
    Stream.Write(WriteCSS[1], Length(WriteCSS));
    Stream.Free;
  end;
end;


end.
