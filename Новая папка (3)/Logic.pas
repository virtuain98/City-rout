unit Logic;

interface

uses
  System.SysUtils, FileUnit, Math;

const
  MAX_DISTANCE = $FFFF;

type
  TLinks = record
    bus : PTTraffic;
    trolBus : PTTraffic;
    tram : PTTraffic;
    metro : PTTraffic;
    time : double;
    distance : double;
  end;

var
  useBus, useTrol, useTram, useMetro : boolean;
  connectMatrix : array of array of TLinks;
  //i, j : integer;

procedure ConnectiveMatrixCreate;
procedure FindRoute;
function GetAnswer(start : boolean) : PTStationList;
function GetDistance(latitude1, longitude1, latitude2, longitude2 : double) : double;
function GetStationPnt(num : integer) : PTStationList;

implementation

var
  maxCount : integer;

function GetDistance(latitude1, longitude1, latitude2, longitude2 : double) : double;
const diameter = 12756200 ;
var   dx, dy, dz:double;
begin
  longitude1 := degtorad(longitude1 - longitude2);
  latitude1 := degtorad(latitude1);
  latitude2 := degtorad(latitude2);

  dz := sin(latitude1) - sin(latitude2);
  dx := cos(longitude1) * cos(latitude1) - cos(latitude2);
  dy := sin(longitude1) * cos(latitude1);
  Result := arcsin(sqrt(sqr(dx) + sqr(dy) + sqr(dz)) / 2) * diameter;
end;

{function CheckDoubleStations(var pnt1, pnt2 : PTStationList) : boolean;
var
  i : integer;
begin
  i := 0;
  while (i < High(pnt1^.name)) and (pnt1^.name[i] <> ':') and (pnt2^.name[i] <> ':')
  and (AnsiLowerCase(pnt1^.name[i]) = AnsiLowerCase(pnt2^.name[i])) do inc(i);
  if (pnt1^.name[i] = ':') and (pnt1^.name[i] = ':') then Result := true
  else Result := false;
end; }

function CheckDistance (var pnt1, pnt2 : PTStationList) : boolean;
begin
  Result := GetDistance(pnt1^.X, pnt1^.Y, pnt2^.X, pnt2^.Y) < 200;
end;

function ConnectiveMatrixPointsTired(pnt1, pnt2 : PTStationList) : boolean;
var
  i, j, num : integer;
begin
  if pnt1 <> pnt2 then
  begin
    Result := false;
    num := StationListGetSize - 1;
    Result := (connectMatrix[pnt1^.num - 1, pnt2^.num - 1].bus <> nil) or
    (connectMatrix[pnt1^.num - 1, pnt2^.num - 1].trolBus <> nil) or
    (connectMatrix[pnt1^.num - 1, pnt2^.num - 1].tram <> nil) or
    (connectMatrix[pnt1^.num - 1, pnt2^.num - 1].metro <> nil) or
    (connectMatrix[pnt2^.num - 1, pnt1^.num - 1].bus <> nil) or
    (connectMatrix[pnt2^.num - 1, pnt1^.num - 1].trolBus <> nil) or
    (connectMatrix[pnt2^.num - 1, pnt1^.num - 1].tram <> nil) or
    (connectMatrix[pnt2^.num - 1, pnt1^.num - 1].metro <> nil);

    //if not Result then Result := CheckDoubleStations(pnt1, pnt2);
    if not Result then Result := CheckDistance(pnt1, pnt2);
  end else Result := false;
end;

procedure ConnectiveMatrixFillTraffic;
var
  head : PTTransportList;
  pnt: PTTrace;
  num : byte;
begin
  head := TransportList^.next;
  while head <> nil do
  begin
    pnt := head^.trace;
    num := GetType(head^.specif);
    while pnt^.next^.enable do
    begin
      case num of
        1 :
          if useBus then
            AddTransport(connectMatrix[pnt^.data^.num - 1, pnt^.next^.data^.num - 1].bus, head);
        2 :
          if useTrol then
            AddTransport(connectMatrix[pnt^.data^.num - 1, pnt^.next^.data^.num - 1].trolBus, head);
        3 :
          if useTram then
            AddTransport(connectMatrix[pnt^.data^.num - 1, pnt^.next^.data^.num - 1].tram, head);
        4 :
          if useMetro then
            AddTransport(connectMatrix[pnt^.data^.num - 1, pnt^.next^.data^.num - 1].metro, head);
        0 : Halt;
      end;
      pnt := pnt^.next;
    end;
    head := head^.next;
  end;
end;

function GetStartStation(trace : PTTrace; station : PTStationList) : PTTrace;
begin
  while trace^.data <> station do trace := trace^.next;
  Result := trace;
end;

function GetFinStation(station : PTTrace) : PTTrace;
var
  pnt, finStation : PTTrace;
begin
  pnt := station;
  while pnt^.enable do pnt := pnt^.next;
  if pnt^.next = pnt then finStation := pnt^.next^.next
  else finStation := pnt^.next;
  pnt := station;
  while pnt^.next^.enable and (pnt <> finStation) do pnt := pnt^.next;
  Result := pnt;
end;

function StationBetween(start, fin : PTTrace; stat : PTStationList) : boolean;
begin
  Result := False;
  while (start <> fin) and not Result do
  begin
    Result := start^.data = stat;
    start := start^.next;
  end;
end;

function StationEnableOnBus(stat1, stat2 : PTStationList) : boolean;
var
  head : PTTraffic;
  pnt, finStation, startStation : PTTrace;
begin
  Result := False;
  if stat1^.bus <> nil then
  begin
    head := stat1^.bus;
    while head <> nil do
    begin
      startStation := GetStartStation(head^.data^.trace, stat1);
      finStation := GetFinStation(startStation);
      if StationBetween(startStation, finStation, stat2) then Result := true;
      if Result then exit;
      head := head^.next;
    end;
    stat1^.bus := stat1^.bus^.next;
  end else if stat1.trolBus <> nil then
  begin
    head := stat1^.trolBus;
    while head <> nil do
    begin
      startStation := GetStartStation(head^.data^.trace, stat1);
      finStation := GetFinStation(startStation);
      if StationBetween(startStation, finStation, stat2) then Result := true;
      if Result then exit;
      head := head^.next;
    end;
    stat1^.trolBus := stat1^.trolBus^.next;
  end;
end;

function StationEnableOnTram(stat1, stat2 : PTStationList) : boolean;
var
  head : PTTraffic;
  startStation, finStation : PTTrace;
begin
  Result := False;
  if stat1^.tram <> nil then
  begin
    head := stat1^.tram;
    while head <> nil do
    begin
      startStation := GetStartStation(head^.data^.trace, stat1);
      finStation := GetFinStation(startStation);
      if StationBetween(startStation, finStation, stat2) then Result := true;
      if Result then exit;
      head := head^.next;
    end;
  end;
end;

function StationEnableOnMetro(stat1, stat2 : PTStationList) : boolean;
var
  head : PTTraffic;
  startStation, finStation : PTTrace;
begin
  Result := False;
  if stat1^.tram <> nil then
  begin
    head := stat1^.metro;
    while head <> nil do
    begin
      startStation := GetStartStation(head^.data^.trace, stat1);
      finStation := GetFinStation(startStation);
      if StationBetween(startStation, finStation, stat2) then Result := true;
      if Result then exit;
      head := head^.next;
    end;
  end;
end;

function StationEnableOnTransport(pnt1, pnt2 : PTStationList) : boolean;
begin
  Result := StationEnableOnBus(pnt1, pnt2) or StationEnableOnTram(pnt1, pnt2) or
  StationEnableOnMetro(pnt1, pnt2);
end;

function GetTime(pnt1, pnt2 : PTStationList) : double;
const
  BUS_SPEED = 12.7 * 1000 / 3600;
  TRAM_SPEED = BUS_SPEED * 0.9;
  METRO_SPEED = 41 * 1000 / 3600;
  ON_FOOT_SPEED = 5.288 * 1000 / 3600;
begin
  Result := 0;
  if StationEnableOnBus(pnt1, pnt2) then
    Result := GetDistance(pnt1^.X, pnt1^.Y, pnt2^.X, pnt2^.Y) / BUS_SPEED
  else if StationEnableOnTram(pnt1, pnt2) then
    Result := GetDistance(pnt1^.X, pnt1^.Y, pnt2^.X, pnt2^.Y) / TRAM_SPEED
  else if StationEnableOnMetro(pnt1, pnt2) then
    Result := GetDistance(pnt1^.X, pnt1^.Y, pnt2^.X, pnt2^.Y) / METRO_SPEED
  else if CheckDistance(pnt1, pnt2) then
    Result := GetDistance(pnt1^.X, pnt1^.Y, pnt2^.X, pnt2^.Y) / ON_FOOT_SPEED;
end;

procedure ConnectiveMatrixFillLinks;
var
  pnt1, pnt2 : PTStationList;
  i, j, k, num : integer;
begin
  pnt1 := stationList^.next;
  pnt2 := stationList^.next;

  while pnt1 <> nil do
  begin
    pnt2 := stationList^.next;
    while pnt2 <> nil do
    begin
      if (pnt1 <> pnt2) and ConnectiveMatrixPointsTired(pnt1, pnt2) then
      begin
        connectMatrix[pnt1^.num - 1, pnt2^.num - 1].time :=
        GetTime(pnt1, pnt2);
        connectMatrix[pnt2^.num - 1, pnt1^.num - 1].time :=
        connectMatrix[pnt1^.num - 1, pnt2^.num - 1].time;
      end;
      pnt2 := pnt2^.next;
    end;
    pnt1 := pnt1^.next;
  end;
end;

procedure ConnectiveMatrixCreate;
var
  i, j, num : integer;
begin
  num := StationListGetSize - 1;
  SetLength(connectMatrix, StationListGetSize - 1);
  for i := 0 to num do
  begin
    SetLength(connectMatrix[i], StationListGetSize - 1);
    for j := 0 to num do
    begin
      connectMatrix[i,j].bus := nil;
      connectMatrix[i,j].trolBus := nil;
      connectMatrix[i,j].tram := nil;
      connectMatrix[i,j].metro := nil;
      connectMatrix[i,j].time := 0;
      connectMatrix[i,j].distance := MAX_DISTANCE;
    end;
  end;

  ConnectiveMatrixFillTraffic;
  ConnectiveMatrixFillLinks;
end;

function GetStationPnt(num : integer) : PTStationList;
var
  pnt : PTStationList;
begin
  pnt := stationList;
  while (pnt <> nil) and (pnt^.num <> num) do pnt := pnt^.next;
  Result := pnt;
end;

//******************************************************************************
//******************************************************************************
function GetAnswer(start : boolean) : PTStationList;
var
  num : integer;
  pnt : PTStationList;
begin
  if start then write (#13, #10'������� �������� �����: ')
  else write (#13, #10'������� ����� ����������: ');

  Readln(num);
  Result := GetStationPnt(num);
end;

procedure PrintList(var list : PTStationList);
begin
  if list^.prev <> nil then PrintList(list^.prev);
  Writeln (list^.name,' ',connectMatrix[list^.prev^.num - 1, list^.num - 1].time,' -> ');
end;
//******************************************************************************
//******************************************************************************

function PointInList(var main, elem : PTStationList) : boolean;
var
  pnt : PTStationList;
begin
  pnt := main;
  while (pnt <> nil) and (pnt <> elem) do pnt := pnt^.prev;
  Result := pnt <> nil;
end;

procedure Dijkstra(var prev, last : PTStationList; distance : double; count : integer);
var
  i, num : integer;
  pnt : PTStationList;
begin
  if (prev <> last) and (count * 2 <= maxCount)   then
  begin
    num := High(connectMatrix) + 1;
    for i := 0 to num do
    begin
      pnt := GetStationPnt(i + 1);
      if (pnt <> prev) and not PointInList(prev, pnt) and
      (connectMatrix[prev^.num - 1, i].time <> 0) then
        if StationEnableOnTransport(prev, pnt) and
        (distance + connectMatrix[prev^.num - 1, i].time -
        connectMatrix[prev^.num - 1, i].distance > 1) then
        begin
          connectMatrix[prev^.num - 1, i].distance :=
          distance + connectMatrix[prev^.num - 1, i].time;
          pnt.prev := prev;
          writeln(prev^.name);
          //Readln;
          Dijkstra(pnt, last, connectMatrix[prev^.num - 1, i].distance, count + 1);
        end else if CheckDistance(prev, pnt) and
        (distance + connectMatrix[prev^.num - 1, i].time + 5 <
        connectMatrix[prev^.num - 1, i].distance) then
        begin
          connectMatrix[prev^.num - 1, i].distance :=
          distance + connectMatrix[prev^.num - 1, i].time + 5;
          pnt.prev := prev;
          writeln(prev^.name);
          //Readln;
          Dijkstra(pnt, last, connectMatrix[prev^.num - 1, i].distance, count + 1);
        end;
    end
  end
  else if (count * 2 <= maxCount) then
  begin
    if distance + connectMatrix[prev^.num - 1, last^.num - 1].time <
    connectMatrix[prev^.num - 1, last^.num - 1].distance then
    begin
      connectMatrix[prev^.num - 1, last^.num - 1].distance :=
      distance + connectMatrix[prev^.num - 1, last^.num - 1].time;
      writeln('����� ������ ', connectMatrix[prev^.num - 1, last^.num - 1].distance : 0 : 3);
      Writeln(#13,#10);
      PrintList(last);
      maxCount := count;
    end;
  end;
end;

procedure FindRoute;
var
  start, last : PTStationList;
  num : integer;
begin
  start := GetAnswer(true);
  last := GetAnswer(false);
  maxCount := StationListGetSize * 2;
  Dijkstra(start, last, 0, 0);
end;

end.
