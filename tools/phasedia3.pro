;----------------------------------------------------------
FUNCTION READ_TABLE, filename, $
                     columns=columns, nrows=nrows, $
                     nmax=nmax, double=double, $
                     text=text, head=head
;----------------------------------------------------------
;+
; NAME:
;       READ_TABLE
;
; PURPOSE:
;       Read an ASCII table into a data array.
;
; AUTHOR:
;       Simon Vaughan (U.Leicester)
;
; CALLING SEQUENCE:
;       data = READ_TABLE('file.dat')
;
; INPUTS:
;       file - (string) file name 
;
; OPTIONAL INPUTS:  
;       columns - (integer vector) which columns of table to retain 
;       nrows   - (integer) number of lines to read 
;       nmax    - (integer) minimum size of file, default is 100,000
;       double  - (logical) whether to use double or single prec.
;       text    - (logical) whether to load text from file       
;       head    - (integer) number of lines to skip in header
;
; OUTPUTS:
;       2-dimensional data array (floating point values)
;
; DETAILS:
;       Data are assumed to be floating point numbers, by
;       default single precision, seperated by spaces in a
;       rectangular grid (ncols*nrow)
;
; Example calls:
;
; IDL> data = read_table('table.txt')
; IDL> data = read_table('table.txt', columns=[2,3])
; IDL> data = read_table('table.txt', n=100, HEAD=1, /TEXT)
;
; HISTORY:
;       Based losely on DDREAD.PRO by Frank Knight (MIT)
;       11/01/2007 -  v1.0 - first working version
;       27/04/2007 -  v1.1 - added TEXT option
;       22/11/2007 -  v1.2 - added HEAD option
;       22/09/2008 -  v1.3 - HEAD now takes integer input
;       16/06/2010 -  v1.4 - fixed handling of text input
;                             using STRSPLIT function.
;       20/07/2012 -  v1.5 - If error encountered then RETURN
;                             a value -1, for consistency with
;                             other routines.
;       28/07/2012 - v1.6  - Replace obsolete FINDFILE with
;                             FILE_SEARCH. Upon error return
;                             !NULL. (New to IDL 8). Use 
;                             QUERY_ASCII to check the file is
;                             indeed ASCII, and to define the
;                             number of rows in the file.
;                              
; NOTES:
;       This is similar to the IDL READ_ASCII function. But
;       it allow you to force the data type. This is useful
;       if the input file comprises columns of different types,
;       e.g. 1 column of strings, 3 columns of floats. In this
;       case use READ_TABLE(..., /TEXT) which will force all
;       columns to be read as strings, and then convert the
;       numerical columns from string to float as needed.
;-
; ----------------------------------------------------------

; options for compilation (recommended by RSI)

  COMPILE_OPT idl2, HIDDEN

; watch out for errors

  ON_ERROR, 0

; ----------------------------------------------------------
; Check the arguments

; is the file name defined?

  IF (N_ELEMENTS(filename) eq 0) THEN BEGIN
      filename = ''
      READ, '-- Enter file name (ENTER to list current directory): ', filename
  ENDIF

  IF (filename eq '') THEN BEGIN
      list = FILE_SEARCH(/TEST_READ, /TEST_REGULAR)
      PRINT, list
      READ,'-- Enter file name: ', filename
  ENDIF

; are we reading in single (=4) or double precision (=5)?
 
  type=4
  IF (KEYWORD_SET(double)) THEN type=5

; are we reading numbers or text?
 
  IF (KEYWORD_SET(text)) THEN type=7
 
; ----------------------------------------------------------
; Checks of the file existance and shape

; check the file exists

  file = (FILE_SEARCH(filename, /TEST_READ, /TEST_REGULAR))
  IF (file[0] eq '') THEN BEGIN
      PRINT,'** File not found.'
      RETURN, !NULL
  ENDIF
  IF (N_ELEMENTS(file) ne 1) THEN BEGIN
      PRINT,'** File not found.'
      RETURN, !NULL
  ENDIF

; check the file is ASCII and count the total number of lines

  check = QUERY_ASCII(file, file_info)
  IF (check eq 0) THEN BEGIN
      PRINT, '** File is not ASCII.'
      RETURN, !NULL
  ENDIF
  file_row = file_info.lines
  IF KEYWORD_SET(head) THEN file_row = file_row - head
  IF NOT KEYWORD_SET(nrows) THEN nrows = file_row
  nrows = (nrows < file_row)
  
; find the number of columns in the file by reading first line
; into a string (tmp)

  ncols = 0
  tmp = ''
  OPENR, lun, file, /GET_LUN
  if KEYWORD_SET(head) THEN BEGIN
      FOR i=0, head-1 DO READF, lun, tmp ; skip header
  ENDIF
  READF, lun, tmp
  FREE_LUN, lun

; remove whitespace

  tmp = ' ' + STRCOMPRESS(STRTRIM(tmp, 2))

; count the spaces (there is one per column)

  FOR i=0, STRLEN(tmp)-1 DO BEGIN
      ncols = ncols + (STRPOS(tmp, ' ', i) eq i)
  END

; ----------------------------------------------------------
; load the data into an array

; define the data array ready to receive data

  data = MAKE_ARRAY(size=[2, ncols, nrows, type, ncols*nrows])

; define a single line (row) array for reading each line
; except for text which is loaded a whole line at a time 

  IF NOT KEYWORD_SET(text) THEN BEGIN
      record = MAKE_ARRAY(size=[1, ncols, type, ncols])
  ENDIF ELSE BEGIN
      record = ''
  ENDELSE

; Open the file ready to read

  OPENR, lun, file, /GET_LUN

; skip header line if HEAD keyword is set

  if KEYWORD_SET(head) THEN BEGIN
      FOR i=0, head-1 DO READF, lun, tmp 
  ENDIF

; Read each line one at a time, until either end-of-file
; or we reach nrows.

  n = 0L
  WHILE (eof(lun) ne 1) DO BEGIN
      ON_IOERROR, IOERR
      error = 1
      READF, lun, record
      error = 0
      IF KEYWORD_SET(text) THEN BEGIN
          data[*, n] = STRSPLIT(record, ' ', /EXTRACT)
      ENDIF ELSE BEGIN
          data[*,n] = record
      ENDELSE
      n = n + 1
      IF (n eq nrows) THEN BREAK

      IOERR:
      IF (error eq 1) THEN BEGIN
          PRINT, '** Error reading line', n, ' in READ_TABLE'
          FREE_LUN, lun
          RETURN, !NULL
      ENDIF

  ENDWHILE

; Close the file

  FREE_LUN, lun

; ----------------------------------------------------------
; Return the data array to the user

; if no column selection, RETURN entire array 

  if (N_ELEMENTS(columns) eq 0) THEN RETURN, data

; otherwise remove unwanted columns before RETURNing

  indx = WHERE((columns ge ncols-1), count)
  IF (count eq 0) THEN BEGIN
      data = data[columns, *]
  ENDIF ELSE BEGIN
      PRINT, '** Requested columns outside allowed range'
      PRINT, '** Returning all columns from READ_TABLE'
  ENDELSE

  RETURN, data

END

;--------------------------------------------------------
PRO SKALA, ni, lev, col, tit, pos, csize
;--------------------------------------------------------
  xmin=min(lev)
  xmax=max(lev)
  yhh=[0,1,2,3,4,5,6,7,8,9,10]
  ahh=fltarr(ni,11)
  for i=0,ni-1 do begin
    for j=0,10 do begin
      ahh(i,j)=lev(i)
    endfor
  endfor
  wide_pos=pos
  wide_pos[0]=wide_pos[0]-0.01
  wide_pos[1]=wide_pos[1]-0.10
  wide_pos[2]=wide_pos[2]+0.01
  wide_pos[3]=wide_pos[3]+0.01
  contour, ahh, lev, yhh, /nodata, /noerase,$
           xrange=[0,1], yrange=[0,1], $
           xstyle=5, ystyle=5, yticks=5, position=wide_pos 
  x=[0.0,1.0,1.0,0.0]
  y=[0.31,0.31,1.0,1.0]
  polyfill,x,y,color=255,noclip=0
  slen = STRLEN(tit)
  for i=0,STRLEN(tit)-1 do begin
    if (strmid(tit,i,1) EQ "!") then slen=slen-2
    if (strmid(tit,i,2) EQ "!L") then slen=slen-1
    if (strmid(tit,i,2) EQ "!U") then slen=slen-1
  endfor  
  w=csize*slen/18.0*0.29
  x=[0.5-w,0.5+w,0.5+w,0.5-w]
  y=[0.03,0.03,0.32,0.32]
  polyfill,x,y,color=255,noclip=0
  contour, ahh, lev, yhh, $
           xrange=[xmin,xmax], yrange=[0,5], xtitle=tit, CHARSIZE=csize, $
           xstyle=1, ystyle=1, yticks=1, ytickname=[' ',' '], $
           levels=lev, /fill, /noerase, c_colors=col, position=pos, $
           noclip=0, xticklen=0.1
end; SKALA

;--------------------------------------------------------
PRO SKALA_VERT, ni, lev, col, tit, pos
;--------------------------------------------------------
  xmin=min(lev)
  xmax=max(lev)
  xhh=[0,1,2,3,4,5,6,7,8,9,10]
  ahh=fltarr(11,ni)
  for i=0,10 do begin
    for j=0,ni-1 do begin
      ahh(i,j)=lev(j)
    endfor
  endfor
  ;
  wide_pos=pos
  wide_pos[0]=wide_pos[0]-0.05
  wide_pos[1]=wide_pos[1]-0.01
  wide_pos[2]=wide_pos[2]+0.05
  wide_pos[3]=wide_pos[3]+0.01
  contour, ahh, xhh, lev, /nodata, /noerase,$
           xrange=[0,1], yrange=[0,1], $
           xstyle=5, ystyle=5, yticks=5, position=wide_pos 
  x=[0,1,1,0]
  y=[0,0,1,1]
  polyfill,x,y,color=255,noclip=0
  contour, ahh, xhh, lev, $
           xrange=[0,5], yrange=[xmin,xmax], CHARSIZE=1.3, $
           xstyle=1, ystyle=1, xticks=1, xtickname=[' ',' '], $
           levels=lev, /fill, /noerase, c_colors=col, position=pos, $
           noclip=0, xticklen=0.1
  xyouts,/normal,pos[2]+0.031,0.5*(pos[1]+pos[3]),tit,$
         orientation=90,alignment=0.5
end; SKALA_VERT

; ----------------------------------------------------------------
; --------------------- main program -----------------------------
; ----------------------------------------------------------------
!p.font=0
!x.style=1
!y.style=1
!z.style=1
!x.margin=[10,3]
!y.margin=[4,2]
!p.charsize=1.3
!x.thick=4
!y.thick=4
xx1=18.0
xx2=17.0
xx3=1.0
xx4=1.0
set_plot,'ps'
device,filename='out.ps'
device,xsize=xx1,ysize=xx2,xoffset=xx3,yoffset=xx4,/color
loadct,39      ; use 0 for B&W output, 39 for rainbow
black   = 0
white   = 255
orange  = 210
red     = 250
yellow  = 195
green   = 160
cyan    = 100
blue    = 70
magenta = 40

filename = 'Static_Conc_2D.dat'
text = ''
header = ''
NELM = 0
NMOL = 0
NDUST = 0
openr,1,filename
readf,1,text
readf,1,NELM,NMOL,NDUST,Npoints
readf,1,header
quant = strsplit(header,/EXTRACT)

stoich1 = dblarr(2,NELM+NMOL)
stoich2 = dblarr(2,NELM+NMOL)
print,"carbon in H-C-N-O ..."
for i=0,NELM+NMOL-1 do begin
  nam = quant(i+4)
  stoich1(*,i) = 0
  stoich2(*,i) = 0
  ii = strpos(nam,"C")
  b1 = strpos(nam,"(")
  b2 = strpos(nam,")")
  if (ii GE 0) then begin
    next0 = strmid(nam,ii,1)
    next1 = strmid(nam,ii+1,1)
    next2 = strmid(nam,ii+2,1)
    if (strpos(" CL CA CR Cl Ca Cr "," "+next0+next1+" ") GE 0) then continue
    stoich1(0,i) = 1.0
    if (next1 GE '0' AND next1 LE '9') then begin
      stoich1(0,i) = double(next1+next2)
    endif
    if (b1 GE 0 and b1 LT ii and b2 GT ii) then begin
      stoich1(0,i) = stoich1(0,i)*double(strmid(nam,b2+1,1))
    endif  
    stoich2(0,i) = stoich1(0,i)
    if (strpos(nam,"CL") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"NA") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"LI") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"MG") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"SI") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"FE") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"NI") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"CR") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"ZR") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"AL") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"TI") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"MN") GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"V")  GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"F")  GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"P")  GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"K")  GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"S")  GE 0) then stoich2(0,i)=0.0
    if (strpos(nam,"W")  GE 0) then stoich2(0,i)=0.0
    if (stoich2(0,i) GT 0.0) then print,nam,stoich1(0,i),stoich2(0,i)
  endif  
endfor
print
print,"oxygen in H-C-N-O ..."
for i=0,NELM+NMOL-1 do begin
  nam = quant(i+4)
  ii = strpos(nam,"O")
  b1 = strpos(nam,"(")
  b2 = strpos(nam,")")
  if (ii GE 0) then begin
    next0 = strmid(nam,ii,1)
    next1 = strmid(nam,ii+1,1)
    next2 = strmid(nam,ii+2,1)
    if (strpos(" CL CA CR Cl Ca Cr "," "+next0+next1+" ") GE 0) then continue
    stoich1(1,i) = 1.0
    if (next1 GE '0' AND next1 LE '9') then begin
      stoich1(1,i) = float(next1+next2)
    endif
    if (b1 GE 0 and b1 LT ii and b2 GT ii) then begin
      stoich1(1,i) = stoich1(1,i)*float(strmid(nam,b2+1,1))
    endif  
    stoich2(1,i) = stoich1(1,i)
    if (strpos(nam,"CL") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"CA") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"LI") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"NA") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"MG") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"SI") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"FE") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"NI") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"CR") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"ZR") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"AL") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"TI") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"MN") GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"V")  GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"F")  GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"P")  GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"K")  GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"S")  GE 0) then stoich2(1,i)=0.0
    if (strpos(nam,"W")  GE 0) then stoich2(1,i)=0.0
    if (stoich2(1,i) GT 0.0) then print,nam,stoich1(1,i),stoich2(1,i)
  endif  
endfor

iT  = where(quant EQ 'Tg')
ip  = where(quant EQ 'pges')
;            0      1       2      3        4          5           6  
Nquant = ['nHges','epsC','epsO','epsCeff','epsOeff','epsCckeck','epsOcheck']
Nq = N_ELEMENTS(Nquant)
iq = INTARR(Nq)
for i=0,2 do begin
  iq(i) = where(quant EQ Nquant(i))
endfor
iq(3)=-1
iq(4)=-1
T  = dblarr(Npoints,Npoints)       ; [K]
p  = dblarr(Npoints,Npoints)       ; [dyn/cm2]
lognH = dblarr(Npoints,Npoints)    ; [1/cm3]
qq = dblarr(Nq,Npoints,Npoints)
ii = 0
for iy=0,Npoints-1 do begin
  for ix=0,Npoints-1 do begin
    if (EOF(1)) then break  
    readf,1,text
    data = strsplit(text,/EXTRACT)
    T(ix,iy) = double(data(iT))
    p(ix,iy) = double(data(ip))
    for i=0,2 do begin
      qq(i,ix,iy) = double(data(iq(i)))
    endfor
    Ctot = 0.0
    Otot = 0.0
    Ceff = 0.0
    Oeff = 0.0
    for j=0,NELM+NMOL-1 do begin
      if (stoich1(0,j) GT 0.0) then begin
        xmol = 10^double(data(4+j)) 
        Ctot = Ctot + stoich1(0,j)*xmol
        Ceff = Ceff + stoich2(0,j)*xmol
      endif
      if (stoich1(1,j) GT 0.0) then begin
        xmol = 10^double(data(4+j)) 
        Otot = Otot + stoich1(1,j)*xmol
        Oeff = Oeff + stoich2(1,j)*xmol
      endif
    endfor
    nH   = qq(0,ix,iy)
    Ctot = Ctot/nH 
    Ceff = Ceff/nH 
    Otot = Otot/nH 
    Oeff = Oeff/nH 
    ;print,qq(1,ix,iy),ALOG10(Ctot),ALOG10(Ceff)
    ;print,qq(2,ix,iy),ALOG10(Otot),ALOG10(Oeff)
    qq(3,ix,iy) = Ceff
    qq(4,ix,iy) = Oeff
    qq(5,ix,iy) = Ctot
    qq(6,ix,iy) = Otot
    ii = ii+1
  endfor
  if (EOF(1)) then break  
endfor
close,1
lognH(*,*) = ALOG10(qq(0,*,*))
logp = ALOG10(p)-6.0               ; log10 p [bar]
pmin = min(logp)
pmax = max(logp)
Tmin = min(T)
Tmax = max(T)
xticks  = [100,200,400,600,1000,2000]
Nxticks = N_ELEMENTS(xticks)
yticks  = [1,0,-1,-2,-3,-4,-5,-6,-7,-8,-9]
Nyticks = N_ELEMENTS(yticks)
lpmin = min(logp)
lpmax = max(logp)
Tmin  = min(T)
Tmax  = max(T)

for iy=0,Npoints-1 do begin
  lnpval = lpmax+(lpmin-lpmax)*iy/(Npoints-1)
  logp(*,iy) = lnpval
endfor
for ix=0,Npoints-1 do begin
  lnTval = alog(Tmax)-alog(Tmax/Tmin)*ix/(Npoints-1)
  T(ix,*) = exp(lnTval)
endfor

;------------------------------------------------------------------------------
yy = dblarr(Npoints,Npoints)
yy(*,*) = 10.d0^qq(4,*,*)
ymax = 0.011
ymin = 0.0
yy(WHERE(yy LT ymin)) = ymin
yy(WHERE(yy GT ymax)) = ymax
ilev = 240
ddd  = (ymax-ymin)/ilev
lev=dblarr(ilev+1)
col=intarr(ilev+1)      
colmin=35
colmax=253
for i=0, ilev do begin
  lev(i)=ymin+ddd*i
  col(i)=fix(colmin+(colmax-colmin)*(lev(i)-ymin)/(ymax-ymin))
endfor
pos=[0.12,0.12,0.98,0.98]

;------------------------------------------------------------------------------
epsC = 10.d0^qq(1,*,*)
epsO = 10.d0^qq(2,*,*)
yy(*,*) = epsC(0,*,*)/epsO(0,*,*)
ymax = 1.0
ymin = 0.5
yy(WHERE(yy LT ymin)) = ymin
yy(WHERE(yy GT ymax)) = ymax
ilev = 240
ddd  = (ymax-ymin)/ilev
lev=dblarr(ilev+1)
col=intarr(ilev+1)      
colmin=35
colmax=253
for i=0, ilev do begin
  lev(i)=ymin+ddd*i
  col(i)=fix(colmin+(colmax-colmin)*(lev(i)-ymin)/(ymax-ymin))
endfor
pos=[0.12,0.12,0.98,0.98]

contour,yy,T,logp,/xlog,$
    xrange=[100,2500],yrange=[1,-9],$
    xminor=2,yminor=2,$
    xticks=Nxticks-1,xtickv=xticks,$
    yticks=Nyticks-1,ytickv=yticks,$
    xticklen=0.03,yticklen=0.025,$
    xtitle='!7T [K]',ytitle='!7log p [bar]',$
    levels=lev, /fill, c_colors=col, position=pos,$
    charthick=3.0,thick=5,xthick=6,ythick=6,charsize=1.7

contour,yy,T,logp,/overplot,level=[0.7,0.8],c_annotation=['0.7','0.8'],$
    c_linestyle=2,c_charsize=1.6,c_thick=6,color=white

SKALA_VERT, ilev+1,lev,col,'C/O',[0.87,0.6,0.89,0.94]

;------------------------------------------------------------------------------
epsC = qq(5,*,*)
epsO = qq(6,*,*)
yy(*,*) = epsC(0,*,*)/epsO(0,*,*)
ymax = 1.0
ymin = 0.5
yy(WHERE(yy LT ymin)) = ymin
yy(WHERE(yy GT ymax)) = ymax
ilev = 240
ddd  = (ymax-ymin)/ilev
lev=dblarr(ilev+1)
col=intarr(ilev+1)      
colmin=35
colmax=253
for i=0, ilev do begin
  lev(i)=ymin+ddd*i
  col(i)=fix(colmin+(colmax-colmin)*(lev(i)-ymin)/(ymax-ymin))
endfor
pos=[0.12,0.12,0.98,0.98]

contour,yy,T,logp,/xlog,$
    xrange=[100,2500],yrange=[1,-9],$
    xminor=2,yminor=2,$
    xticks=Nxticks-1,xtickv=xticks,$
    yticks=Nyticks-1,ytickv=yticks,$
    xticklen=0.03,yticklen=0.025,$
    xtitle='!7T [K]',ytitle='!7log p [bar]',$
    levels=lev, /fill, c_colors=col, position=pos,$
    charthick=3.0,thick=5,xthick=6,ythick=6,charsize=1.7

contour,yy,T,logp,/overplot,level=[0.58,0.8],c_annotation=['0.58','0.8'],$
    c_linestyle=2,c_charsize=1.6,c_thick=6,color=white

SKALA_VERT, ilev+1,lev,col,'(C/O)!Lcheck!N',[0.87,0.6,0.89,0.94]

;------------------------------------------------------------------------------
epsC = qq(3,*,*)
epsO = qq(4,*,*)
yy(*,*) = epsC(0,*,*)/epsO(0,*,*)
ymax = 1.0
ymin = 0.5
yy(WHERE(yy LT ymin)) = ymin
yy(WHERE(yy GT ymax)) = ymax
ilev = 240
ddd  = (ymax-ymin)/ilev
lev=dblarr(ilev+1)
col=intarr(ilev+1)      
colmin=35
colmax=253
for i=0, ilev do begin
  lev(i)=ymin+ddd*i
  col(i)=fix(colmin+(colmax-colmin)*(lev(i)-ymin)/(ymax-ymin))
endfor
pos=[0.12,0.12,0.98,0.98]

contour,yy,T,logp,/xlog,$
    xrange=[100,2500],yrange=[1,-9],$
    xminor=2,yminor=2,$
    xticks=Nxticks-1,xtickv=xticks,$
    yticks=Nyticks-1,ytickv=yticks,$
    xticklen=0.03,yticklen=0.025,$
    xtitle='!7T [K]',ytitle='!7log p [bar]',$
    levels=lev, /fill, c_colors=col, position=pos,$
    charthick=3.0,thick=5,xthick=6,ythick=6,charsize=1.7

contour,yy,T,logp,/overplot,level=[0.58,0.8],c_annotation=['0.58','0.8'],$
    c_linestyle=2,c_charsize=1.6,c_thick=6,color=white

SKALA_VERT, ilev+1,lev,col,'(C/O)!Leff!N',[0.87,0.6,0.89,0.94]

device,/close
set_plot,'x'
print,"... output written to out.ps"
stop

END
