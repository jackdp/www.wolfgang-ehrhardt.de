
(*************************************************************************
 Include file for Blowfish CTR Seek routines. These routines are in a separate 
 inc  file because they are included in BF_ctr.pas for non-dlls AND in the dll
 interface units BF_Intv/BF_Intf. This is done in order to make tests like
 @IncProc=@BF_IncMSBPart work without additional overhead in programs using
 the dll.

 Version  Date      Author      Modification
 -------  --------  -------     ------------------------------------------
 0.10     05.08.10  W.Ehrhardt  Initial version
**************************************************************************)

(****** (C) Copyright 2010  Wolfgang Ehrhardt -- see copying_we.txt ******)

{---------------------------------------------------------------------------}
function  BF_CTR_Seek({$ifdef CONST}const{$else}var{$endif} iCTR: TBFBlock;
                       SOL, SOH: longint; var ctx: TBFContext): integer;
  {-Setup ctx for random access crypto stream starting at 64 bit offset SOH*2^32+SOL,}
  { SOH >= 0. iCTR is the initial CTR for offset 0, i.e. the same as in BF_CTR_Init.}
var
  i,pt: integer;
  carry: word;
  TC: TBFBlock;
type
  TBA4 = packed array[0..3] of byte;
  TWA2 = packed array[0..1] of longint;
begin

  {WARNING: CTR mode demands that the same key / iCTR pair is never reused  }
  {for encryption. This requirement is especially important for the CTR_Seek}
  {function. If different data is written to the same position there will be}
  {leakage of information about the plaintexts. Therefore CTR_Seek should   }
  {normally be used for random reads only.}

  if SOH < 0 then begin
    BF_CTR_Seek := BF_Err_CTR_SeekOffset;
    exit;
  end
  else with ctx do begin
    blen := word(SOL) and $07;
    {64 bit shift right (SOH, SOL) 3 bits}
    SOL := (SOL shr 3) or ((SOH and $07) shl 29);
    SOH := (SOH shr 3);
    {Check if known IncProc}
    {$ifdef FPC_ProcVar}
      if (IncProc=nil) or (IncProc=@BF_IncMSBFull) then pt := 1
      else if IncProc=@BF_IncMSBPart then pt := 2
      else if IncProc=@BF_IncLSBFull then pt := 3
      else if IncProc=@BF_IncLSBPart then pt := 4
      else pt := 0;
    {$else}
      if (@IncProc=nil) or (@IncProc=@BF_IncMSBFull) then pt := 1
      else if @IncProc=@BF_IncMSBPart then pt := 2
      else if @IncProc=@BF_IncLSBFull then pt := 3
      else if @IncProc=@BF_IncLSBPart then pt := 4
      else pt := 0;
    {$endif}
    IV := iCTR;

    if (SOL or SOH) <> 0 then begin
      if pt=0 then begin
        {No shortcut calculation for user-defined IncProcs. Note: SOH is }
        {positive here even if the sign bit of the original SOH was set. }

        {The execution of this loop may be very time-consuming because the }
        {IncProc is called many times. If the user is able to calculate the}
        {value IVo of the iCTR after calling IncProc (offset div 16) times,}
        {invoking the function with  BF_CTR_Seek(IVo, SOL and 15, 0, ctx) }
        {will completely skip the IncProc calculation, but set the correct }
        {values for ctx.IV, ctx.buf, and ctx.blen.}
        if SOL=0 then dec(SOH);
        repeat
          repeat
            IncProc(IV);
            dec(SOL);
          until SOL=0;
          dec(SOH);
        until SOH<=0;
      end
      else begin
        carry := 0;
        if (pt=1) or (pt=2) then begin
          {MSB functions, first fill 64 bit offset vector}
          for i:=0 to 3 do begin
            TC[7-i] := TBA4(SOL)[i];
            TC[3-i] := TBA4(SOH)[i];
          end;
          {64 bit addition}
          for i:=7 downto 4 do begin
            carry := carry + TC[i] + IV[i];
            IV[i] := carry and $FF;
            carry := carry shr 8;
          end;
          if (pt=1) and (carry<>0) then begin
            {"Full" function: propagate carry through remaining bytes}
            for i:=3 downto 0 do begin
              carry := carry + IV[i];
              IV[i] := carry and $FF;
              carry := carry shr 8;
              {$ifdef CONST}
                if carry=0 then break;
              {$endif}
            end;
          end;
        end
        else begin
          {LSB functions, first fill 64 bit offset vector}
          TWA2(TC)[0] := SOL;
          TWA2(TC)[1] := SOH;
          {64 bit addition}
          for i:=0 to 3 do begin
            carry := carry + TC[i] + IV[i];
            IV[i] := carry and $FF;
            carry := carry shr 8;
          end;
          if (pt=3) and (carry<>0) then begin
            {"Full" function: propagate carry through remaining bytes}
            for i:=4 to 7 do begin
              carry := carry + IV[i];
              IV[i] := carry and $FF;
              carry := carry shr 8;
              {$ifdef CONST}
                if carry=0 then break;
              {$endif}
            end;
          end;
        end;
      end;
    end;
    BF_Encrypt(ctx, IV, buf);
    BF_CTR_Seek := 0;
  end;
end;


{$ifdef HAS_INT64}
{-----------------------------------------------------------------------------}
function BF_CTR_Seek64(const iCTR: TBFBlock; SO: int64; var ctx: TBFContext): integer;
  {-Setup ctx for random access crypto stream starting at 64 bit offset SO >= 0;}
  { iCTR is the initial CTR value for offset 0, i.e. the same as in BF_CTR_Init.}
type
  LH = packed record L,H: longint; end;
begin
  BF_CTR_Seek64 := BF_CTR_Seek(iCTR, LH(SO).L, LH(SO).H, ctx);
end;
{$endif}
