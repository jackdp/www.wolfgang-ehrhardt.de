unit ANU_ECB;

(*************************************************************************

 DESCRIPTION   :  Anubis (tweaked) ECB functions

 REQUIREMENTS  :  TP5-7, D1-D7/D9-D10/D12, FPC, VP

 EXTERNAL DATA :  ---

 MEMORY USAGE  :  ---

 DISPLAY MODE  :  ---

 REFERENCES    :  B.Schneier, Applied Cryptography, 2nd ed., ch. 9.1


 Version  Date      Author      Modification
 -------  --------  -------     ------------------------------------------
 0.10     05.08.08  W.Ehrhardt  Initial version analog AES_ECB
 0.11     24.11.08  we          Uses BTypes
 0.12     01.08.10  we          Longint ILen in ANU_ECB_En/Decrypt
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
function ANU_ECB_Init_Encr(const Key; KeyBits: word; var ctx: TANUContext): integer;
  {-Anubis key expansion, error if invalid key size, encrypt IV}
  {$ifdef DLL} stdcall; {$endif}
function ANU_ECB_Init_Decr(const Key; KeyBits: word; var ctx: TANUContext): integer;
  {-Anubis key expansion, error if invalid key size, encrypt IV}
  {$ifdef DLL} stdcall; {$endif}
{$else}

function ANU_ECB_Init_Encr(var Key; KeyBits: word; var ctx: TANUContext): integer;
  {-Anubis key expansion, error if invalid key size, encrypt IV}

function ANU_ECB_Init_Decr(var Key; KeyBits: word; var ctx: TANUContext): integer;
  {-Anubis key expansion, error if invalid key size, encrypt IV}

{$endif}


function ANU_ECB_Encrypt(ptp, ctp: Pointer; ILen: longint; var ctx: TANUContext): integer;
  {-Encrypt ILen bytes from ptp^ to ctp^ in ECB mode}
  {$ifdef DLL} stdcall; {$endif}

function ANU_ECB_Decrypt(ctp, ptp: Pointer; ILen: longint; var ctx: TANUContext): integer;
  {-Decrypt ILen bytes from ctp^ to ptp^ in ECB mode}
  {$ifdef DLL} stdcall; {$endif}


implementation


{---------------------------------------------------------------------------}
function ANU_ECB_Init_Encr({$ifdef CONST} const {$else} var {$endif} Key; KeyBits: word; var ctx: TANUContext): integer;
  {-Anubis key expansion, error if invalid key size}
begin
  {-Anubis key expansion, error if invalid key size}
  ANU_ECB_Init_Encr := ANU_Init_Encr(Key, KeyBits, ctx);
end;


{---------------------------------------------------------------------------}
function ANU_ECB_Init_Decr({$ifdef CONST} const {$else} var {$endif} Key; KeyBits: word; var ctx: TANUContext): integer;
  {-Anubis key expansion, error if invalid key size}
begin
  {-Anubis key expansion, error if invalid key size}
  ANU_ECB_Init_Decr := ANU_Init_Decr(Key, KeyBits, ctx);
end;


{---------------------------------------------------------------------------}
function ANU_ECB_Encrypt(ptp, ctp: Pointer; ILen: longint; var ctx: TANUContext): integer;
  {-Encrypt ILen bytes from ptp^ to ctp^ in ECB mode}
var
  i,n: longint;
  m: word;
  tmp: TANUBlock;
begin

  ANU_ECB_Encrypt := 0;
  if ILen<0 then ILen := 0;

  if ctx.Decrypt<>0 then begin
    ANU_ECB_Encrypt := ANU_Err_Invalid_Mode;
    exit;
  end;

  if (ptp=nil) or (ctp=nil) then begin
    if ILen>0 then begin
      ANU_ECB_Encrypt := ANU_Err_NIL_Pointer;
      exit;
    end;
  end;

  {$ifdef BIT16}
    if (ofs(ptp^)+ILen>$FFFF) or (ofs(ctp^)+ILen>$FFFF) then begin
      ANU_ECB_Encrypt := ANU_Err_Invalid_16Bit_Length;
      exit;
    end;
  {$endif}

  n := ILen div ANUBLKSIZE; {Full blocks}
  m := ILen mod ANUBLKSIZE; {Remaining bytes in short block}
  if m<>0 then begin
    if n=0 then begin
      ANU_ECB_Encrypt := ANU_Err_Invalid_Length;
      exit;
    end;
    dec(n);           {CTS: special treatment of last TWO blocks}
  end;

  {Short block must be last, no more processing allowed}
  if ctx.Flag and 1 <> 0 then begin
    ANU_ECB_Encrypt := ANU_Err_Data_After_Short_Block;
    exit;
  end;

  with ctx do begin
    for i:=1 to n do begin
      ANU_Encrypt(ctx, PANUBlock(ptp)^, PANUBlock(ctp)^);
      inc(Ptr2Inc(ptp),ANUBLKSIZE);
      inc(Ptr2Inc(ctp),ANUBLKSIZE);
    end;
    if m<>0 then begin
      {Cipher text stealing}
      ANU_Encrypt(ctx, PANUBlock(ptp)^, buf);
      inc(Ptr2Inc(ptp),ANUBLKSIZE);
      tmp := buf;
      move(PANUBlock(ptp)^, tmp, m);
      ANU_Encrypt(ctx, tmp, PANUBlock(ctp)^);
      inc(Ptr2Inc(ctp),ANUBLKSIZE);
      move(buf,PANUBlock(ctp)^,m);
      {Set short block flag}
      Flag := Flag or 1;
    end;
  end;
end;


{---------------------------------------------------------------------------}
function ANU_ECB_Decrypt(ctp, ptp: Pointer; ILen: longint; var ctx: TANUContext): integer;
  {-Decrypt ILen bytes from ctp^ to ptp^ in ECB mode}
var
  i,n: longint;
  m: word;
  tmp: TANUBlock;
begin

  ANU_ECB_Decrypt := 0;
  if ILen<0 then ILen := 0;

  if ctx.Decrypt=0 then begin
    ANU_ECB_Decrypt := ANU_Err_Invalid_Mode;
    exit;
  end;

  if (ptp=nil) or (ctp=nil) then begin
    if ILen>0 then begin
      ANU_ECB_Decrypt := ANU_Err_NIL_Pointer;
      exit;
    end;
  end;

  {$ifdef BIT16}
    if (ofs(ptp^)+ILen>$FFFF) or (ofs(ctp^)+ILen>$FFFF) then begin
      ANU_ECB_Decrypt := ANU_Err_Invalid_16Bit_Length;
      exit;
    end;
  {$endif}

  n := ILen div ANUBLKSIZE; {Full blocks}
  m := ILen mod ANUBLKSIZE; {Remaining bytes in short block}
  if m<>0 then begin
    if n=0 then begin
      ANU_ECB_Decrypt := ANU_Err_Invalid_Length;
      exit;
    end;
    dec(n);           {CTS: special treatment of last TWO blocks}
  end;

  {Short block must be last, no more processing allowed}
  if ctx.Flag and 1 <> 0 then begin
    ANU_ECB_Decrypt := ANU_Err_Data_After_Short_Block;
    exit;
  end;

  with ctx do begin
    for i:=1 to n do begin
      ANU_Decrypt(ctx, PANUBlock(ctp)^, PANUBlock(ptp)^);
      inc(Ptr2Inc(ptp),ANUBLKSIZE);
      inc(Ptr2Inc(ctp),ANUBLKSIZE);
    end;
    if m<>0 then begin
      {Cipher text stealing}
      ANU_Decrypt(ctx, PANUBlock(ctp)^, buf);
      inc(Ptr2Inc(ctp),ANUBLKSIZE);
      tmp := buf;
      move(PANUBlock(ctp)^, tmp, m);
      ANU_Decrypt(ctx, tmp, PANUBlock(ptp)^);
      inc(Ptr2Inc(ptp),ANUBLKSIZE);
      move(buf,PANUBlock(ptp)^,m);
      {Set short block flag}
      Flag := Flag or 1;
    end;
  end;
end;

end.
