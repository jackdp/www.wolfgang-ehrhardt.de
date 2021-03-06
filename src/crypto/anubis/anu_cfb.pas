unit ANU_CFB;

(*************************************************************************

 DESCRIPTION   :  Anubis (tweaked) CFB128 functions
                  Because of buffering en/decrypting is associative

 REQUIREMENTS  :  TP5-7, D1-D7/D9-D10/D12, FPC, VP

 EXTERNAL DATA :  ---

 MEMORY USAGE  :  ---

 DISPLAY MODE  :  ---

 REFERENCES    :  B.Schneier, Applied Cryptography, 2nd ed., ch. 9.6


 Version  Date      Author      Modification
 -------  --------  -------     ------------------------------------------
 0.10     05.08.08  W.Ehrhardt  Initial version analog AES_CFB
 0.11     24.11.08  we          Uses BTypes
 0.12     01.08.10  we          Longint ILen in ANU_CFB_En/Decrypt
**************************************************************************)


(*-------------------------------------------------------------------------
 (C) Copyright 2008-2010 Wolfgang Ehrhardt

 This software is provided 'as-is', without any express or implied warranty.
 In no event will the authors be held liable for any damages arising from
 the use of this software.

 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:

 1. The origin of this software must not be misrepresented; you must not
    claim that you wrote the original software. If you use this software in
    a product, an acknowledgment in the product documentation would be
    appreciated but is not required.

 2. Altered source versions must be plainly marked as such, and must not be
    misrepresented as being the original software.

 3. This notice may not be removed or altered from any source distribution.
----------------------------------------------------------------------------*)

{$i STD.INC}

interface


uses
  BTypes, ANU_Base;

{$ifdef CONST}
function ANU_CFB_Init(const Key; KeyBits: word; const IV: TANUBlock; var ctx: TANUContext): integer;
  {-Anubis key expansion, error if invalid key size, encrypt IV}
  {$ifdef DLL} stdcall; {$endif}
{$else}
function ANU_CFB_Init(var Key; KeyBits: word; var IV: TANUBlock; var ctx: TANUContext): integer;
  {-Anubis key expansion, error if invalid key size, encrypt IV}
{$endif}

function ANU_CFB_Encrypt(ptp, ctp: Pointer; ILen: longint; var ctx: TANUContext): integer;
  {-Encrypt ILen bytes from ptp^ to ctp^ in CFB128 mode}
  {$ifdef DLL} stdcall; {$endif}

function ANU_CFB_Decrypt(ctp, ptp: Pointer; ILen: longint; var ctx: TANUContext): integer;
  {-Decrypt ILen bytes from ctp^ to ptp^ in CFB128 mode}
  {$ifdef DLL} stdcall; {$endif}


implementation


{---------------------------------------------------------------------------}
{$ifdef CONST}
function ANU_CFB_Init(const Key; KeyBits: word; const IV: TANUBlock; var ctx: TANUContext): integer;
{$else}
function ANU_CFB_Init(var Key; KeyBits: word; var IV: TANUBlock; var ctx: TANUContext): integer;
{$endif}
  {-Anubis key expansion, error if invalid key size, encrypt IV}
var
  err: integer;
begin
  {-Anubis key expansion, error if invalid key size}
  err := ANU_Init_Encr(Key, KeyBits, ctx);
  ANU_CFB_Init := err;
  if err=0 then begin
    {encrypt IV}
    ANU_Encrypt(ctx, IV, ctx.IV);
  end;
end;


{---------------------------------------------------------------------------}
function ANU_CFB_Encrypt(ptp, ctp: Pointer; ILen: longint; var ctx: TANUContext): integer;
  {-Encrypt ILen bytes from ptp^ to ctp^ in CFB128 mode}
begin
  ANU_CFB_Encrypt := 0;

  if ctx.Decrypt<>0 then begin
    ANU_CFB_Encrypt := ANU_Err_Invalid_Mode;
    exit;
  end;

  if (ptp=nil) or (ctp=nil) then begin
    if ILen>0 then begin
      ANU_CFB_Encrypt := ANU_Err_NIL_Pointer;
      exit;
    end;
  end;

  {$ifdef BIT16}
    if (ofs(ptp^)+ILen>$FFFF) or (ofs(ctp^)+ILen>$FFFF) then begin
      ANU_CFB_Encrypt := ANU_Err_Invalid_16Bit_Length;
      exit;
    end;
  {$endif}

  if ctx.blen=0 then begin
    {Handle full blocks first}
    while ILen>=ANUBLKSIZE do with ctx do begin
      {Cipher text = plain text xor encr(IV/CT), cf. [3] 6.3}
      ANU_XorBlock(PANUBlock(ptp)^, IV, PANUBlock(ctp)^);
      ANU_Encrypt(ctx, PANUBlock(ctp)^, IV);
      inc(Ptr2Inc(ptp), ANUBLKSIZE);
      inc(Ptr2Inc(ctp), ANUBLKSIZE);
      dec(ILen, ANUBLKSIZE);
    end;
  end;

  {Handle remaining bytes}
  while ILen>0 do with ctx do begin
    {Test buffer empty}
    if bLen>=ANUBLKSIZE then begin
      ANU_Encrypt(ctx, buf, IV);
      bLen := 0;
    end;
    buf[bLen] := IV[bLen] xor pByte(ptp)^;
    pByte(ctp)^ := buf[bLen];
    inc(bLen);
    inc(Ptr2Inc(ptp));
    inc(Ptr2Inc(ctp));
    dec(ILen);
  end;
end;


{---------------------------------------------------------------------------}
function ANU_CFB_Decrypt(ctp, ptp: Pointer; ILen: longint; var ctx: TANUContext): integer;
  {-Decrypt ILen bytes from ctp^ to ptp^ in CFB128 mode}
begin
  ANU_CFB_Decrypt := 0;

  if ctx.Decrypt<>0 then begin
    ANU_CFB_Decrypt := ANU_Err_Invalid_Mode;
    exit;
  end;

  if (ptp=nil) or (ctp=nil) then begin
    if ILen>0 then begin
      ANU_CFB_Decrypt := ANU_Err_NIL_Pointer;
      exit;
    end;
  end;

  {$ifdef BIT16}
    if (ofs(ptp^)+ILen>$FFFF) or (ofs(ctp^)+ILen>$FFFF) then begin
      ANU_CFB_Decrypt := ANU_Err_Invalid_16Bit_Length;
      exit;
    end;
  {$endif}

  if ctx.blen=0 then begin
    {Handle full blocks first}
    while ILen>=ANUBLKSIZE do with ctx do begin
      {plain text = cypher text xor encr(IV/CT), cf. [3] 6.3}
      {must use buf, otherwise overwrite bug if ctp=ptp}
      buf := PANUBlock(ctp)^;
      ANU_XorBlock(buf, IV, PANUBlock(ptp)^);
      ANU_Encrypt(ctx, buf, IV);
      inc(Ptr2Inc(ptp), ANUBLKSIZE);
      inc(Ptr2Inc(ctp), ANUBLKSIZE);
      dec(ILen, ANUBLKSIZE);
    end;
  end;

  {Handle remaining bytes}
  while ILen>0 do with ctx do begin
    {Test buffer empty}
    if bLen>=ANUBLKSIZE then begin
      ANU_Encrypt(ctx, buf, IV);
      bLen := 0;
    end;
    buf[bLen] := pByte(ctp)^;
    pByte(ptp)^ := buf[bLen] xor IV[bLen];
    inc(bLen);
    inc(Ptr2Inc(ptp));
    inc(Ptr2Inc(ctp));
    dec(ILen);
  end;
end;

end.
