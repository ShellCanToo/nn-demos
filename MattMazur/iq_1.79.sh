#!/bin/sh
# - iQalc or 'iq' is a precision decimal calculator for the shell

# Copyright Gilbert Ashley 5 July 2023
# Contact: perceptronic@proton.me  Subject-line: iQalc

# Operations supported: addition, subtraction, multiplication, division,
# remainder, modulo, rounding and numeric comparison of decimal values.

# To see the iq help page, run './iq -h' (or 'iq -h' if 'iq' is in your PATH)
# See the bottom of the file for full instructions on using iq.

# disable some style checks from shellcheck
# shellcheck disable=SC2086,SC2004,SC2295,SC2123,SC2068,SC2145,SC2048,SC2154,SC2015,SC1090,SC1091,SC2181

# new Interactive Mode for use like other common CLI calculators
# vets all commanads and allows loading extra functions as modules
# new function: validate_inputs - check for valid and appropriate operators and inputs
# complete re-write of input validation, reducing in-loop testing in add, mul and div
# add - 5 less case patterns/structures; mul - 6 less
# div - speedup of fraction calculation (see qlimit)
# div - rewrote calculation of modulo which agrees with most on-line
#       modulo calculators, as well as python(%) & Java floorMod
# div - add 'qr' operator, which returns both quotient and remainder
# mul - check at top if any input = 0, and return answer zero
# corrected cases of constructs like '$var1$var2' -use ${var1}$var2
# spow moved to iq_misc
# round new function performs ceiling, floor, half-up or half-even rounding and truncation(towards-zero rounding)
# mul  div - implemented rounding option
# add still does no rounding, but one can do this: iq round hfup -s4 $(iq add -s5 1.23456 2.0 )
# added SC2154,SC2015,SC1090,SC1091,SC2181

iqversion=1.79

# default precision
defprec=${defprec:-5}

# tsst  - numeric comparison of decimal numbers using shell 'test' syntax
# depends on: 'cmp3w'
tsst_help(){
echo "  'tsst' usage: 'tsst num1 (operator) num2' 
    Operators: -lt -le -eq -ge -gt -ne
    tsst returns true or false condition, for use like shell 'test' or '[' 
    Example: 'tsst 4.22 -lt 6.3 && echo less'
    Example: 'tsst 4.22 -lt 6.3 ; echo \$?'"
}
tsst() { case $1 in ''|-h|-s*) tsst_help >&2 ; return 1 ;;esac
    tstret=$( cmp3w $1 $3 )
    case $2 in
        '-lt') [ "$tstret" = '<' ] ; return $? ;;
        '-le')  case $tstret in '<'|'=') return 0 ;; *) return 1 ;;esac ;;
        '-eq') [ "$tstret" = '=' ] ; return $? ;;
        '-ge')  case $tstret in '>'|'=') return 0 ;; *) return 1 ;;esac ;;
        '-gt') [ "$tstret" = '>' ] ; return $? ;;
        '-ne')  case $tstret in '=') return 1 ;; *) return 0 ;;esac ;;
    esac
} ## tsst
# tstret=

# 'cmp3w' compares 2 decimal numbers relatively, returning: '<', '=' or '>'
# depends on: /bin/sh
# used by: 'tsst' 'add' 'div'
# The input-handling routine used here, is similar to that used in most other
# functions so it's commented here, and later only where it differs from here
cmp3w_help() { 
echo "  'cmp3w' usage: 'cmp3w num1 num2' 
    Relatively compares 2 decimal numbers, returns: '<' '=' or '>'
    Example: 'cmp3w -234.57 -234.55' returns: '<' (to stdout)"
}
cmp3w() { case $1 in ''|-h|-s*) cmp3w_help >&2  ; return 1 ;;esac
    # separate and store the signs of both inputs
    case $1 in '-'*) c1sign='-' c1=${1#*-} ;; *) c1sign='+' c1=${1#*+} ;;esac
    case $2 in '-'*) c2sign='-' c2=${2#*-} ;; *) c2sign='+' c2=${2#*+} ;;esac
    # separate the integer and fractional parts
    case $c1 in *.*) c1i=${c1%.*} c1f=${c1#*.} ;; *) c1i=$c1 c1f=0  ;;esac
    case $c2 in *.*) c2i=${c2%.*} c2f=${c2#*.} ;; *) c2i=$c2 c2f=0 ;;esac
    # default zeros
    c1i=${c1i:-0} c1f=${c1f:-0} c2i=${c2i:-0} c2f=${c2f:-0}
    # pad both integers and fractions until equal in length
    while [ ${#c1i} -gt ${#c2i} ] ;do c2i='0'$c2i ;done 
    while [ ${#c2i} -gt ${#c1i} ] ;do c1i='0'$c1i ;done
    while [ ${#c1f} -gt ${#c2f} ] ;do c2f=$c2f'0' ;done 
    while [ ${#c2f} -gt ${#c1f} ] ;do c1f=$c1f'0' ;done
    # recombine each number into an equi-length integer string
    c1=${c1i}$c1f c2=${c2i}$c2f
    # if both inputs are >18-digits, work left-to-right in chunks of 18 chars
    while [ ${#c1} -gt 18 ] ;do
        cmpmsk1=${c1#*??????????????????} cmp1=${c1%"${cmpmsk1}"*} 
        cmpmsk2=${c2#*??????????????????} cmp2=${c2%"${cmpmsk2}"*}
        c1=$cmpmsk1 c2=$cmpmsk2
        # if both chunks are only zeros, skip to next chunk
        case ${cmp1}$cmp2 in *[!0]*) : ;; *) continue ;;esac
        # Check (signed) for '>' or '<' condition. Prepended 1's protect any embedded zeros
        [ $c1sign'1'"$cmp1" -gt $c2sign'1'"$cmp2" ] && { echo '>' ; return ;}
        [ $c1sign'1'"$cmp1" -lt $c2sign'1'"$cmp2" ] && { echo '<' ; return ;}
    done
    # Do the same for inputs under 19 digits, or last chunks from above
    case ${c1}$c2 in *[!0]*) : ;; *) echo '=' ; return ;;esac
    [ $c1sign'1'"$c1" -gt $c2sign'1'"$c2" ] && { echo '>' ; return ;}
    [ $c1sign'1'"$c1" -lt $c2sign'1'"$c2" ] && { echo '<' ; return ;}
    # if we get here the numbers are definitely equal
    echo '='
} ## cmp3w
#c1= c1i= c1f= c1sign= c2= c2i= c2f= c2sign= cmp1= cmp2= cmpmsk1= cmpmsk2= 

# add - add and/or subtract 2 or more decimal numbers
# depends on: 'cmp3w' 'validate_inputs'
# adds or subtracts large numbers in chunks of 16 digits
add_help() {
echo "  'add' usage: 'add [-s?] num1 [+-] num2 ...' 
  
    If scale is omitted or '-soff', no truncation is done
    Example: 'add 2.340876 + 1827.749048' = 1830.089924
    Example: 'add 2.340876 - 1827.749048' = -1825.408172
    
    Otherwise, result is truncated to the given scale
    Example: 'add -s4 2.340876 + 1827.749048' = 1830.0899
    
    If scale is zero '-s0', output is in integer form
    Example: 'add -s0 2.340876 1827.749048' = 1830
    
    Results are only truncated after a series of inputs.
  "
}
add(){ aprec=off
    case $1 in -s*) aprec=${1#*-s} ; shift ;; ''|-h) add_help >&2 ; return 1 ;;esac
    
    # make sure we have only valid numbers and appropriate operators for add
    validate_inputs add $aprec $* || { echo "->add: Invalid input in '-s$aprec' '$@'" >&2 ; return 1 ; }
    
    # initial sum is the first input
    r_add=$1 ; shift
    while [ "$1" ] ;do
        # if next input is operator, record it and shift to next input
        case $1 in +|-) aoprtr=$1 ; shift ;;esac
        # get the next number
        anxt=$1
    
        # separate any signs from the numbers and establish positive/negative state of result
        case $r_add in -*) rsign='-' r_add=${r_add#*-} ;; *) rsign='+' r_add=${r_add#*+} ;;esac
        case $anxt in -*) anxtsign='-' anxt=${anxt#*-} ;; *) anxtsign='+' anxt=${anxt#*+} ;;esac
        # separate the integer and fraction parts of both numbers -dont allow single or trailing dot
        case $r_add in .*) rint=0 rfrac=${r_add#*.} ;; *.*) rint=${r_add%.*} rfrac=${r_add#*.} ;;
            *) rint=$r_add rfrac=0 ;;esac
        case $anxt in .*) nint=0 nfrac=${anxt#*.} ;; *.*) nint=${anxt%.*} nfrac=${anxt#*.} ;;
            *) nint=$anxt nfrac=0 ;;esac
            
        # pad fractions till equal-length = 'write one number above the other, aligning the decimal points'
        while [ ${#rfrac} -lt ${#nfrac} ] ;do rfrac=$rfrac'0' ;done
        while [ ${#nfrac} -lt ${#rfrac} ] ;do nfrac=$nfrac'0' ;done
        # get the size of the fraction after padding them
        afsize=${#rfrac}
        # front-pad integers till equal-length for accurate chunking.
        # This also means we are sending pre-formatted numbers to cmp3w
        while [ ${#rint} -lt ${#nint} ] ;do rint='0'$rint ;done
        while [ ${#nint} -lt ${#rint} ] ;do nint='0'$nint ;done
        # when an operator is used we need this step to handle these forms: 'a + -b', 'a - -b', 'a - +b'
        [ -n "$aoprtr" ] && case ${aoprtr}${anxtsign} in '++'|'--') anxtsign='+' ;; '+-'|'-+') anxtsign='-' ;;esac 
        # put _larger_ number first for an easier work-flow -we've pre-padded so this is fast
        case $( cmp3w '1'${rint}$rfrac '1'${nint}$nfrac ) in '<')  swpint=$rint swpfrac=$rfrac swpsign=$rsign 
            rint=$nint rfrac=$nfrac rsign=$anxtsign nint=$swpint nfrac=$swpfrac anxtsign=$swpsign ;;esac
        # the sign of the result, rsign, is the sign of the greater number(absolute value)
        
        # find the real operation we will be performing
        case ${rsign}${anxtsign} in '+-'|'-+') aoprtr='-' ;; *) aoprtr='+' ;;esac
        
        # assign recombined values to A and B, and recycle r_add
        A=${rint}$rfrac B=${nint}$nfrac r_add='' 
        case $aoprtr in 
        '+')    adsub=0 acry=0
            # work from right to left, just like doing it on paper
            # protect embedded 0's in chunks with leading 1's. This also
            # allows to easily check if a carry is triggered
            while [ ${#A} -gt 16 ] ;do
                admsk1=${A%????????????????*} Achnk='1'${A#*$admsk1} A=$admsk1    
                admsk2=${B%????????????????*} Bchnk='1'${B#*$admsk2} B=$admsk2
                adsub=$(( $Achnk + $Bchnk + $acry )) 
                # If result begins with '3', there was a carry
                case $adsub in 3*) acry=1 ;; *) acry=0 ;;esac
                # remove the extra leading digit which is a '2' or '3'
                r_add=${adsub#*?}$r_add 
            done
            # same for any last chunk or the original which was <17 digits
            if [ -n "$A" ] ; then
                Achnk='1'$A Bchnk='1'$B  adsub=$(( $Achnk + $Bchnk + $acry ))
                # if there was a carry(a leading 3), replace with '1'
                # otherwise we simply remove the leading '2'
                case $adsub in 3*) r_add='1'${adsub#*?}$r_add acry=0 ;; 
                    *) r_add=${adsub#*?}$r_add ;;
                esac
            fi
        ;;
        '-')
            if [ ${#A} -lt 19 ] ;then
                # if numbers are <19 digits, do short method
                # prepend a dummy '1' avoids depadding
                A='1'$A B='1'$B
                r_add=$(( $A - $B )) 
            else
                # subtract by chunks - first char of result is a signal for borrow
                adsub=0  acry=0
                # For subtraction, prepending 1's doesn't help us. We'd have to detect
                # the length of the result for borrow detection and decide whether
                # or not to remove the first digit of result. Using leading '3' and '1'
                # makes detection easy and the leading digit of result is always removed
                while [ ${#A} -ge 17 ] ;do
                    admsk1=${A%?????????????????*}  Achnk='3'${A#*$admsk1}  A=$admsk1
                    admsk2=${B%?????????????????*}  Bchnk='1'${B#*$admsk2}  B=$admsk2
                    [ "$acry" = 1 ] && { Bchnk=$(( $Bchnk + 1 ))  acry=0 ;}
                    adsub=$(( $Achnk - $Bchnk ))
                    # prepending 3 and 1 to the numbers above provides
                    # a borrow/carry signal in the first digit from the result
                    # if adsub begins with '2' no carrow/borrow was triggered
                    case $adsub in 1*) acry=1 ;;esac
                    # the leading 3/1 combination assures a constant result length
                    # so we don't have ask whether the result is shorter
                    adsub=${adsub#*?}
                    r_add=${adsub}$r_add
                done
                if [ -n "$A" ] ; then
                    # remove any left-over _extra_ leading zeros from both numbers
                    # we may have a carry, so we can't simply prepend 1's here
                    while : ; do case $A in '0'?*) A=${A#*?} ;; *) break ;;esac ;done
                    while : ; do case $B in '0'?*) B=${B#*?} ;; *) break ;;esac ;done
                    # just as above, use carry instead of borrow
                    [ "$acry" = 1 ] && { B=$(( $B + 1 ))  acry=0 ;}
                    adsub=$(( $A - $B ))
                    r_add=${adsub}$r_add
                fi
            fi
        esac
        # remove any neg sign -we already know what sign the result is
        r_add=${r_add#*-}
        # if result is shorter than frac size, front-pad till equi-length
        while [ ${#r_add} -lt $afsize ] ;do r_add='0'$r_add ;done   
        # separate the fraction from the result, working right-to-left
        adcnt=0   ofrac=''
        while [ $adcnt -lt $afsize ] ;do 
            admsk1=${r_add%?*} ofrac=${r_add#$admsk1*}$ofrac r_add=$admsk1 adcnt=$((adcnt+1))
        done
        # trim leading zeros, # dont leave '-' sign if answer is 0
        while : ;do case $r_add in '0'?*) r_add=${r_add#*?} ;; *) break ;;esac ;done
        # if answer is zero, make sure sign is not '-'
        case ${r_add}$ofrac in *[!0]*) : ;; *) rsign='' ;;esac
        # add the sign unless it's '+'
        r_add=${rsign#*+}${r_add:-0}'.'${ofrac:-0}
        # sanitize these variables for the next round, if any
        aoprtr='' anxtsign='' rsign=''
        shift 1
    done
    
    case $aprec in 
        0) echo ${r_add%.*} ;; off) echo $r_add ;; 
        *)  ofrac=${r_add#*.}
            while [ ${#ofrac} -gt $aprec ] ;do ofrac=${ofrac%?*} ;done
            # remove trailing zeros ??
            while : ; do  case $ofrac in *?0) ofrac=${ofrac%?*} ;; *) break ;;esac ;done
            echo ${r_add%.*}'.'$ofrac ;;
    esac
    # sanitize exit variables
    aprec='' r_add='' ofrac=''
} ## add
# aoprtr= anxt= rsign= anxtsign= rint= rfrac= nint= nfrac= afsze= swpint= swpfrac= swpsign= aprec= r_add= 
# A= B= adsub= acry= admsk1= Achnk= admsk2= Bchnk= adcnt= ofrac=

# mul - multiply 2 or more decimal numbers
# depends on 'add' 'validate_inputs' 'round'
# for large numbers, multiplies in chunks of 9 digits
mul_help() {
echo "  'mul' usage: 'mul [-s?] [-r...] num1 [xX] num2 ...'
  
    If the scale option is omitted or set to off '-soff',
    no truncation or rounding of the result is done.
    Example: 'mul 2.340876445 x 1827.74904' = 4278.5346751073628
    
    If scale is set to zero, result is truncated to integer.
    Example: 'mul -s0 2.340876445 x 1827.74904' = 4278
    
    Otherwise, final result is truncated to the given scale.
    Example: 'mul -s4 2.340876445 X 1827.74904' = 4278.5347
    
    Or, use the '-r..' option to round results, choosing from:
    -roff or -rtrnc to truncate, -rhfev for half-even, 
    -rhfup for half-up, -rceil for ceiling, -rfloor for flooring.
    Example: 'mul -s4 -roff 2.340876445 1827.74904' = 4278.5346
    Example: 'mul -s2 -rceil 2.340876445 1827.74904' = 4278.54
    
    If the result is shorter than the given scale, then the
    answer is exact and no rounding or truncation is done.
    Results are only truncated or rounded after the final
    calculation of a series of inputs.
    
  "
}
mul(){ mprec=off rprec=$mprec
    case $1 in -s*) mprec=${1#*-s} rprec=$mprec ; shift ;; ''|-h) mul_help >&2 ; return 1 ;;esac
    case $1 in -r*) rnd=${1#*-r} rprec=$mprec ; [ "$rprec" != off ] && mprec=$((mprec+1)) ; shift ;;esac
    
    # make sure we have only valid numbers and appropriate operators for mul
    validate_inputs mul $mprec $@ || { echo "->mul: Invalid input in '-s$mprec' '$@'" >&2 ; return 1 ; }
    
    [ "$mprec" = 0 ] && defzero=''
    # exit early if any input is zero, the answer will always be 0 
    # any variants of zero which get by here will be handled below
    case " $@ " in *" 0 "*|*" .0 "*|*" 0.0 "*) echo "0$defzero" ; return ;;esac
    
    r_mul=$1 ; shift
    while [ "$1" ] ;do  
        case $1 in x|X) shift ;;esac
        mnxt=$1
        case $r_mul in -*) mrsign='-' r_mul=${r_mul#*-} ;; *) mrsign='+' r_mul=${r_mul#*+} ;;esac
        case $mnxt in -*) mnxtsign='-' mnxt=${mnxt#*-} ;; *) mnxtsign='+' mnxt=${mnxt#*+} ;;esac
        case $r_mul in  .*) mrint=0 mrfrac=${r_mul#*.} ;; *.*) mrint=${r_mul%.*} mrfrac=${r_mul#*.} ;; 
            *) mrint=$r_mul mrfrac=0 ;;esac
        case $mnxt in  .*) mnint=0 mnfrac=${mnxt#*.} ;; *.*) mnint=${mnxt%.*} mnfrac=${mnxt#*.} ;; 
            *) mnint=$mnxt mnfrac=0 ;;esac
        # remove all leading zeros from integers
        while : ;do case $mrint in '0'*) mrint=${mrint#*?} ;; *) break ;;esac ;done
        while : ;do case $mnint in '0'*) mnint=${mnint#*?} ;; *) break ;;esac ;done 
        # also remove all trailing zeros from fractions
        while : ;do case $mrfrac in *'0') mrfrac=${mrfrac%?*} ;; *) break ;;esac ;done
        while : ;do case $mnfrac in *'0') mnfrac=${mnfrac%?*} ;; *) break ;;esac ;done
        # combine numbers
        Am=${mrint}$mrfrac  Bm=${mnint}$mnfrac  fastm=0
        if [ $(( ${#Am} + ${#Bm} )) -lt 19 ] ; then
            # get the full size of the result fraction
            mfsize=$(( ${#mrfrac} + ${#mnfrac} ))
            # if the integer portion is 0(null), also remove leading zeros from fractions
            [ -z $mrint ] && while : ;do case $mrfrac in '0'*) mrfrac=${mrfrac#*?} ;; *) break ;;esac ;done
            [ -z $mnint ] && while : ;do case $mnfrac in '0'*) mnfrac=${mnfrac#*?} ;; *) break ;;esac ;done
            fastm=1
        else
            # make sure _longer_ number is first for easier chunking
            if [ ${#Am} -lt ${#Bm} ] ; then
                swpint=$mrint swpfrac=$mrfrac swpsign=$mrsign mrint=$mnint mrfrac=$mnfrac mrsign=$mnxtsign 
                mnint=$swpint mnfrac=$swpfrac mnxtsign=$swpsign 
            fi
            mfsize=$(( ${#mrfrac} + ${#mnfrac} ))
        fi
        # determine the sign of result
        case ${mrsign}${mnxtsign} in '++'|'--') R_msign='+' ;; '+-'|'-+') R_msign='-' ;;esac
        
        # recombine numbers and reuse original input r_mul
        Am=${mrint}$mrfrac  Bm=${mnint}$mnfrac  r_mul=0
        
        # if either or both is '1', setup to skip calculation below
        # also check for zero(null) -even though we checked inputs
        # a zero could emerge from an underflow
        case $Am in '') echo 0$defzero ; return ;; 1) r_mul=$Bm ;;esac
        case $Bm in '') echo 0$defzero ; return ;; 1) r_mul=$Am ;;esac
        
        if [ "${Am}$Bm" = "11" ] ; then
            r_mul=1
        elif [ "$r_mul" = 0 ] ; then
            case $fastm in 1) r_mul=$(( $Am * $Bm )) ;;
                # long numbers get chunked
                *)  mchnksize=9 ocol=''
                    while [ -n "$Am" ] ;do
                        # if smaller than chunk size, use all, otherwise take a bite
                        if [ ${#Am} -lt $mchnksize ] ; then
                            Amchnk=$Am Am='' 
                        else
                            mumsk1=${Am%?????????*} Amchnk=${Am#*$mumsk1} Am=$mumsk1
                        fi
                        # depad
                        while : ;do case $Amchnk in '0'*) Amchnk=${Amchnk#*?} ;; *) break ;;esac ;done
                        if [ -n "$Amchnk" ] ; then
                            Bm=${mnint}$mnfrac mtmp=0 icol='' # reset
                            
                            while [ -n "$Bm" ] ;do 
                                if [ ${#Bm} -lt $mchnksize ] ; then
                                    Bmchnk=$Bm Bm=''
                                else
                                    mumsk2=${Bm%?????????*} Bmchnk=${Bm#*$mumsk2} Bm=$mumsk2
                                fi
                                # depad
                                while : ;do case $Bmchnk in '0'*) Bmchnk=${Bmchnk#*?} ;; *) break ;;esac ;done
                                if [ -n "$Bmchnk" ] ; then
                                    mchnk=''
                                    case $Amchnk'_'$Bmchnk in 
                                        1_1) mchnk=1 ;; 1_*) mchnk=$Bmchnk ;; *_1) mchnk=$Amchnk ;;
                                        *)  mchnk=$(( $Amchnk * $Bmchnk )) ;;
                                    esac
                                    mtmp=$( add -s0 $mtmp  ${mchnk}$icol )
                                fi
                                icol=$icol'000000000'
                            done
                            # add the temporary result to total
                            case $r_mul in 
                                    0) r_mul=${mtmp}$ocol ;;
                                    *) r_mul=$( add -s0 $r_mul ${mtmp}$ocol ) ;;
                            esac
                        fi
                        ocol=$ocol'000000000' icol=''
                    done
                ;;
            esac
        fi
        # process ouput from this round the same way as with 'add'
        r_mul=${r_mul#*-}
        while [ ${#r_mul} -lt $mfsize ] ;do r_mul='0'$r_mul ;done
        icol=''   mtmp=0  mcnt=0   mfrac=''
        # separate frac -right to left
        while [ $mcnt -lt $mfsize ] ;do 
            mumsk1=${r_mul%?*} mfrac=${r_mul#*$mumsk1}$mfrac r_mul=$mumsk1 mcnt=$((mcnt+1))
        done
        # depad _extra_ zeros on both sides of result
        while : ;do case $r_mul in '0'?*) r_mul=${r_mul#*?} ;; *) break ;;esac ;done
        while : ;do case $mfrac in *?'0') mfrac=${mfrac%?*} ;; *) break ;;esac ;done
        case ${r_mul:-0}'.'${mfrac:-0} in 0.0) R_msign='' ;;esac
        r_mul=${R_msign#*+}${r_mul:-0}'.'${mfrac:-0}
        R_msign=''
        shift
    done
    
    case $rprec in 
        0)  echo ${r_mul%.*} ;; off) echo $r_mul ;;
        *)  mfrac=${r_mul#*.}
            if [ ${#mfrac} -lt $rprec ] ; then
                # answer is exact, so just remove trailing zeros
                while : ; do  case $mfrac in *?0) mfrac=${mfrac%?*} ;; *) break ;;esac ;done
                echo ${r_mul%.*}'.'$mfrac
            else
                case $rnd in 
                    off|'') while [ ${#mfrac} -gt $rprec ] ;do mfrac=${mfrac%?*} ;done
                        while : ; do  case $mfrac in *?0) mfrac=${mfrac%?*} ;; *) break ;;esac ;done
                        echo ${r_mul%.*}'.'$mfrac ;;
                    #'') pad=5 cnt=0 
                    #    while [ $cnt -lt $mprec ] ; do pad="0$pad" ; cnt=$((cnt+1)) ; done
                    #    case $r_mul in '-'*) add -s$rprec '-.'$pad $r_mul ;; *) add -s$rprec '.'$pad $r_mul ;;esac ;;
                    *) round $rnd -s$rprec $r_mul ;;
                esac
            fi
        ;;
    esac
    
    mfrac='' mprec='' r_mul=''
} ## mul
# mprec= r_mul= mnxt= mrsign= mnxtsign= mrint= mrfrac= mnint= mnfrac= mfsize= mfrac= mtmp= mcnt=
# swpint= swpfrac= swpsign= fastm= R_msign= Am= Bm= Amchnk= Bmchnk= icol= ocol= mchnk= mpad= mumsk1= mumsk2=

# div - perform division '/' or modulo '%' on 2 decimal numbers
# depends on: 'cmp3w' 'tsst' 'add' 'mul' 'validate_inputs' 'round'
# this a one-shot function which, unlike 'add' and 'mul', doesn't accept a series of inputs
div_help() { 
echo "  'div' usage: 'div [-s?] [-r..] num1 ( / % m qr ) num2'
    
    Numbers can be any size integer or decimal
    'div' requires an operator: / % m or 'qr'
    Example: 'div -s8 3.52 / 1.4' = 2.51428571
    If not given, default scale ($defprec) is used:
    Example: 'div 3.52 / 1.4' = 2.51428
    Example: 'div -s0 3.52 / 1.4' = 2
    
    Remainder and Modulo operations:
    div -s8 -3.52 / 1.4 = -2.51428571
    '%' returns the shell-and-C-style remainder
    div -s2 -3.52 % 1.4 = -0.72
    'm' returns the floored python-style modulo
    div -s2 -3.52 m 1.4 = 0.68
    'qr' returns both the quotient and remainder
    div -s2 -3.52 qr 1.4 = -2.0 -0.72
    
    The '-r...' option performs rounding of full division,
    where '...' is hfup(half-up), hfev(half_even), ceil or floor.
    div -s20  -2.340876 / 17.749048         = -0.13188741165159956748
    div -s17 -2.340876 / 17.749048          = -0.13188741165159956
    div -s17 -rhfup  -2.340876 / 17.749048  = -0.13188741165159957
    No rounding is done when performing modulo operations.
    
  "
}
div() { scale_div=$defprec
    case $1 in -s*) scale_div=${1#*-s} ; shift ;; ''|-h) div_help >&2 ; return 1 ;;esac
    case $1 in -r*) rnd=${1#*-r} ; shift ;;esac
    r_div=$scale_div ; scale_div=$((scale_div+1))
    
    # require exactly 3 inputs
    [ -z $3 ] || [ -n "$4" ] && { div_help >&2 ; return 1 ;}
    
    # make sure we have only valid scale, input numbers and appropriate operators for div
    validate_inputs div $scale_div $@ || { echo "->div: Invalid input in '-s$scale_div' '$@'" >&2 ; return 1 ; }
    M=$1 oprtr=$2 D=$3
    
    case $M in '-'*) M_sign='-' M=${M#*-} ;; *) M_sign='+' M=${M#*+} ;;esac
    case $D in '-'*) D_sign='-' D=${D#*-} ;; *) D_sign='+' D=${D#*+} ;;esac
    case "${M_sign}${D_sign}" in '++'|'--') Q_sign='+' ;; '+-'|'-+') Q_sign='-' ;;esac
    case $M in .?*) M_int='' M_frac=${M#*.} ;; *.*) M_int=${M%.*} M_frac=${M#*.} ;;
        *) M_int=${M} M_frac='' ;;esac
    case $D in  .*) D_int='' D_frac=${D#*.} ;; *.*) D_int=${D%.*} D_frac=${D#*.} ;;
        *) D_int=${D} D_frac='' ;;esac
    # remove all leading zeros from integers
    while : ;do case $M_int in '0'*) M_int=${M_int#*?} ;; *) break ;;esac ;done
    while : ;do case $D_int in '0'*) D_int=${D_int#*?} ;; *) break ;;esac ;done
    # remove any trailing zeros from fractions
    while : ;do case $M_frac in *'0') M_frac=${M_frac%?*} ;; *) break ;;esac ;done
    while : ;do case $D_frac in *'0') D_frac=${D_frac%?*} ;; *) break ;;esac ;done
    # save sanitized fractions for comparison below
    sane_mfrac=${M_frac:-0}     sane_dfrac=${D_frac:-0}
    
    # if either number has an integer part eqal to zero, then we need to remove any
    # leading zeros from the fraction and calculate the offset to restore them in answer
    me=0 de=0
    case $M_int in 
        '') while : ;do case $M_frac in '0'*) M_frac=${M_frac#*?} me=$((me-1)) ;; *) break ;;esac ;done ;; 
        *) me=${#M_int} ;;
    esac
    case $D_int in 
        '') while : ;do case $D_frac in '0'*) D_frac=${D_frac#*?} de=$((de-1)) ;; *) break ;;esac ;done ;; 
        *) de=${#D_int} ;;
    esac
    # punch is the offset
    punch=$(( me - de ))
    
    # combine numbers
    mod=${M_int}$M_frac dvsr=${D_int}$D_frac
    # test early for division by zero or easy answers
    case $dvsr in '') echo "->div: Division by zero" >&2 ; return 1 ;;esac

    [ "$r_div" = 0 ] && defzero=''
    # if mod is zero, the answer is '0'
    case $mod in '') echo 0$defzero ; return ;;esac
    
    # special cases for early exit
    case "${D_int:-0}"'.'"$sane_dfrac" in 1.0)
            # denominator is 1, so answer equals numerator
            case $oprtr in 
                '/') Q_out=${Q_sign#*+}${M_int:-0} ; [ "$scale_div" != 0 ] && Q_out=$Q_out'.'$sane_mfrac ;;
                '%'|'m') Q_out='0' ; [ "$sane_mfrac" != 0 ] && Q_out=${M_sign#*+}'0.'$sane_mfrac ;;
            esac
            echo $Q_out ; return ;;
        "${M_int:-0}"'.'"$sane_mfrac") 
            # numerator and denominator are equal, so answer equals 1
            case $oprtr in 
                '/') Q_out=${Q_sign#*+}1$defzero ;;
                '%'|'m') Q_out='0'$defzero ;;
            esac
            echo $Q_out ; return ;;
    esac
    
    # pad both numbers to equal length
    while [ ${#mod} -lt ${#dvsr} ] ;do mod=$mod'0' ;done
    while [ ${#dvsr} -lt ${#mod} ] ;do dvsr=$dvsr'0' ;done
    
    # when punch is negative, it means that the answer is going to be less than 1,
    # and we may need to front-pad the result to restore leading zeros
    case $punch in -*) tsst $mod -ge $dvsr && punch=$((punch+1)) ;;esac
    
    Q_int=0
    # if numerator is greater than denominator, then answers' integer 'Q_int' must be calculated
    if tsst ${M_int:-0}'.'$sane_mfrac -gt ${D_int:-0}'.'$sane_dfrac ; then
        qcnt=0
        while [ $qcnt -lt $punch ] ; do qcnt=$((qcnt+1))
            # if dvsr has trailing zeros, shorten it instead of making mod longer
            case $dvsr in *?0) dvsr=${dvsr%?*} ;; *) mod=$mod'0' ;;esac
        done
        
        if [ ${#mod} -lt 19 ] ; then
            Q_int=$(( $mod / $dvsr )) 
            mod=$(( $mod % $dvsr ))
        else
            # this is division by subtraction using partitioning
            while : ;do
                case $mod in ?) divpad='' ;;
                    *)  seed=$(( ${#mod} - ${#dvsr} )) qcnt=0
                        while [ $qcnt -lt $seed ] ;do divpad=$divpad'0' qcnt=$((qcnt+1)) ;done
                        case $( cmp3w ${dvsr}$divpad $mod ) in '>') divpad=${divpad%?*} ;;esac
                    ;;
                esac
                last_intrm_P=${dvsr}$divpad
                for fctr in 2 3 4 5 6 7 8 9 ;do
                    intrm_P=$( mul -s0 $fctr ${dvsr}$divpad )
                    case $( cmp3w  $intrm_P $mod ) in
                        '>') fctr=$(( $fctr - 1 )) intrm_P=$last_intrm_P ; break ;;
                        '=') break ;;esac
                    last_intrm_P=$intrm_P
                done
                tsst $mod -lt $dvsr && break
                intrm_Q=${fctr}$divpad Q_int=$( add -s0 $Q_int $intrm_Q )
                mod=$( add -s0 $mod - $intrm_P ) divpad='' fctr=''
            done
        fi
    fi
    
    # early exit if operator is %, m or qr
    case $oprtr in '%'|'m'|'qr')
        # restore magnitude and sign of remainder
        mod=$( mul -s$scale_div ${Q_sign#*+}$Q_int x ${D_sign#*+}${D_int:-0}'.'$sane_dfrac )
        mod=$( add -s$r_div ${M_sign#*+}${M_int:-0}'.'$sane_mfrac - $mod )
        case $oprtr in 
            # if oprtr is % (remainder) return modulus
            '%') echo $mod ; return ;;
            # if oprtr is mod (divmod) return quotient and remainder
            'qr') echo ${Q_sign#*+}${Q_int:-0}${defzero} ${mod} ; return ;;
        esac
        # if signs are different, add the divisor, to yield a
        # floored modulo, like python, online-calculators, etc
        case ${M_sign}${D_sign} in 
            '+-'|'-+') mod=$( add -s$r_div $mod + ${D_sign#*+}${D_int:-0}'.'$sane_dfrac ) ;;
        esac
        echo $mod
        return ;;
    esac
    # or if scale is zero
    case $r_div in 0) 
        [ "$Q_int" = 0 ] && echo $Q_int || echo ${Q_sign#*+}$Q_int 
        return ;; 
    esac
    
    # calculate fraction digit-by-digit
    Q_frac=''
    case $punch in -*) qlimit=$(( ${punch} + ${scale_div} ));;
        *) qlimit=$scale_div ;;
    esac
    # for numbers <19 digits
    if [ ${#mod} -lt 18 ] && [ ${#dvsr} -lt 19 ] ;then
        while [ ${#mod} -lt 18 ] ;do
            [ "$mod" = 0 ] && break
            mod=$mod'0'
            if [ $mod -lt $dvsr ] ;then
                Q_frac=$Q_frac'0'
            else
                this_q=$(( $mod / $dvsr ))
                Q_frac=${Q_frac}$this_q
                mod=$(( $mod % $dvsr ))
            fi
            [ ${#Q_frac} -ge ${qlimit} ] && break
        done
    fi
    # there may be partial results above which get finished below
    # calculate fraction using subtraction for long numbers
    while [ ${#Q_frac} -lt $qlimit ] ;do
        [ "$mod" = 0 ] && break
        mod=$mod'0'
        if tsst $mod -lt $dvsr ;then
            Q_frac=$Q_frac'0'
        else    qcnt=0
            while : ;do
                tsst $mod -lt $dvsr && break
                mod=$( add -s0 $mod - $dvsr ) 
                qcnt=$(( qcnt + 1 ))
            done
            Q_frac=${Q_frac}$qcnt
        fi
    done
    # add leading zeros back to fraction where needed
    qcnt=0
    case $punch in -*)
        while [ $qcnt -lt ${punch#*-} ] ;do Q_frac='0'$Q_frac qcnt=$((qcnt+1)) ;done ;;
    esac
    
    if [ ${#Q_frac} -lt $r_div ] ; then
        # remove trailing zeros from fraction
        while : ; do  case $Q_frac in *?0) Q_frac=${Q_frac%?*} ;; *) break ;;esac ;done
        echo ${Q_sign#*+}$Q_int'.'${Q_frac:-0}
    else
        case $rnd in 
            off|'') while [ ${#Q_frac} -gt $r_div ] ;do Q_frac=${Q_frac%?*} ; done
                 echo ${Q_sign#*+}$Q_int'.'${Q_frac:-0} ;;
            #'') pad=5 cnt=0 
            #    while [ $cnt -lt $r_div ] ; do pad="0$pad" ; cnt=$((cnt+1)) ; done
            #    add -s$r_div ${Q_sign#*+}'.'$pad + ${Q_sign#*+}$Q_int'.'${Q_frac:-0} ;;
            *) round $rnd -s$r_div ${Q_sign#*+}$Q_int'.'${Q_frac:-0} ;;
        esac
    fi
    Q_sign='' Q_int='' Q_frac=''
} ## div
# scale_div= M= oprtr= D= M_sign= D_sign= Q_sign= M_int= D_int= M_frac= D_frac= mod= dvsr= Q_fracsize= Q_int= Q_frac=
# qcnt= this_q= seed= divpad= last_intrm_P= fctr= intrm_P= punch= me= de= sane_mfrac= sane_dfrac= qlimit= rounding= Q=

#round_help=" 'round' usage: round (ceil|floor|hup|hev) [-s?] decimal-number"
round_help(){
echo "  'round' usage: round (method) [-s?] decimal-number
  
  Where 'method' is 'ceil' 'flor' 'hfup' 'hfev' or 'trnc'. 
  That is, ceiling, floor, half-up, half-even or truncation
  which is effectively toward-zero rounding.
  Note that 'method' comes before the '-s?' scale option.
  
  Example: 'round ceil -s0 4.001' returns '5'
  Example: 'round floor -s2 -4.001' returns '-4.01'
  Example: 'round hup -s2 4.005' returns '4.01'
  Example: 'round hev -s9 0.9999999985' returns '0.999999998'
  Example: 'round hev -s9 0.9999999995' returns '1.000000000'
  
  "
}
round() { rnd_scale=$defprec
    case $1 in ''|-h) round_help >&2 ; return ;; *) method=$1 ; shift ;;esac
    case $1 in -s*) rnd_scale=${1#*-s} ; shift ;;esac
    case $1 in *.*) int=${1%%.*} frac=${1#*.} ;; 
        '') echo "-> round: Missing input" >&2 ; return ;; 
        *) int=$1 frac='0' ;;
    esac
    case $int in -*) sign='-' int=${int#*-} ;; *) sign='' int=${int#*+} ;;esac
    # truncate, or round-toward-zero is easy out
    case $method in trnc|trunc) while [ ${#frac} -gt $rnd_scale ] ;do frac=${frac%?*} ;done
            # remove trailing zeros ??
            while : ; do  case $frac in *?0) frac=${frac%?*} ;; *) break ;;esac ;done
            echo ${sign}${int}'.'$frac
            return ;;
    esac
    oldfrac=$frac
    
    case $rnd_scale in 
        0) mask=${int%?*} ; lastchar=${int#*"$mask"} ;;
        *) cnt=0 ; pad=''
            while [ $cnt -lt ${rnd_scale} ] ;do 
                mask=${frac#*?} ; char=${frac%${mask}*}
                newfrac="$newfrac${char}" ; frac=$mask
                pad='0'"$pad" ; cnt=$((cnt+1))
            done
            lastchar=$char
        ;;
    esac
    
    mask=${frac#*?} ; char2round=${frac%${mask}*}
    
    case $method in
        ceil)   if [ '-' = "$sign" ] ; then
                     case $rnd_scale in 0) out="-"$int ;; *) out="-"$int'.'${newfrac:-0} ;;esac
                else
                    case $rnd_scale in 
                        0) tsst ${oldfrac:-0} -eq 0  && out=$int || out=$( add -s0 $int + 1 ) ;;
                        *)  [ ${char2round:-0} = 0 ] || pad=${pad#*?}'1'
                            out=$( add -s$rnd_scale '.'${pad:-0} + $int'.'${newfrac:-0}$char2round ) ;;
                    esac
                fi
        ;;
        floor|flor)  
                if [ '-' = "$sign" ] ; then
                    case $rnd_scale in
                        0)  tsst ${oldfrac} -eq 0 && out="-"$int || out="-"$( add -s0 $int + 1 ) ;;
                        *)  [ ${char2round:-0} = 0 ] || pad=${pad#*?}'1'
                            out=${sign#*+}$( add -s$rnd_scale '.'${pad} + $int'.'${newfrac:-0}$char2round ) ;;
                    esac
                else
                    case $rnd_scale in 0) out=$int ;; *) out=$int'.'${newfrac:-0} ;;esac
                fi
        ;;
        # half-up
        hup|hfup) pad=$pad'5'
            out=${sign#*+}$( add -s$rnd_scale '.'$pad + $int'.'${newfrac}$char2round )  ;;
        # half-even
        hev|hfev) signal=$( cmp3w $char2round 5) 
            case $signal in '=')
                    if [ $(( ${lastchar:-0} % 2 )) = "0"  ] ; then
                        # if previous digit is even, truncate
                        # but only if the rest of the fraction is zero
                        case $mask in 
                            *[!0]*) pad=$pad'5' newfrac="$newfrac${char2round}"
                                    out=${sign#*+}$( add -s$rnd_scale '.'$pad + $int'.'${newfrac:-0} ) ;;
                                *) out=${sign#*+}$int'.'${newfrac:-0} ;;
                        esac
                    else
                        # if odd, round half-up
                        pad=$pad'5' newfrac="$newfrac${char2round}"
                        out=${sign#*+}$( add -s$rnd_scale '.'$pad + $int'.'${newfrac:-0} )
                    fi
                ;;
                '>')  newfrac="$newfrac${char2round}" ; pad=${pad}'5'
                      out=${sign#*+}$( add -s$rnd_scale '.'$pad + $int'.'${newfrac:-0} )
                ;;
                '<')
                    case $rnd_scale in 0) out=${sign#*+}$int ;; *) out=${sign#*+}$int'.'${newfrac:-0} ;;esac
                ;;
            esac
        ;;
    esac
    pad=''
    echo $out
}

# as the name says, do nothing. For measuring startup latency, like this: 'time iq do_nothing
do_nothing() { : ;} ## do_nothing

# validate_inputs
# checks all inputs to add, mul and div
# make sure scale value is positive integer, or off
# make sure operators are appropriate to named function
# make sure all values are well-formed numbers
# trailing decimals '1.' are not allowed unlike python, others
validate_inputs() { fun=$1 ; shift ; vscale=$1 ; shift
    case ${vscale#*-s} in off) : ;; *[!0-9]*) return 1 ;;esac
    raw="$*"
    while [ "$1" ] ; do
        if [ ${#1} = 1 ] ; then
            case $fun in
                add) case $1 in +|-) shift ; continue ;;esac ;; mul) case $1 in x|X) shift ; continue ;;esac ;;
                div) case $1 in '/'|'%'|'m') shift ; continue ;;esac ;;
            esac
            case $1 in '.') return 1 ;; # single dot
                [xX/%m^+-]) return 1 ;; # two operators in a row
            esac
        fi
        case $1 in 'qr') shift ;;esac # allow this 2-char operator
        # allow only well-formed numbers
        case $1 in 
            *[!+0-9.-]*) return 1 ;; # is not only digits, dots and signs
            *'.'*'.'*|*+*+*|*-*-*) return 1 ;; # multiple dots
            *'.'|*-|*+) return 1 ;; # trailing dot or signs
            *+*-*|*-*+*) return 1 ;; # multiple signs, mixed signs
            [0-9]*-*|[0-9]*+*) return 1 ;; # signs embedded in digits
        esac
        shift
    done
    # last argument to functions can't be an operator
    case $fun in
        add) case $raw in *+|*-) return 1 ;;esac ;; 
        mul) case $raw in *x|*X) return 1 ;;esac ;;
        div) case $raw in *'/'|*'%'|*'m'|*'qr') return 1 ;;esac ;; 
    esac
    
}

# the general help for iq
iqhelp() {
echo "          IQ - Version $iqversion - Copyright 2023 Gilbert Ashley
    Precision Decimal calculator for CLI, environment or scripts
    
    Main functions/operators: | add + - | mul xX | div / % m qr |
    Comparison functions: | tsst -lt -le -eq -ge -gt -ne | cmp3w |
    
    To show usage, call a function with no argument or '-h':
    'add -h' shows: 'add' usage: 'add [-s?] num1 [+-] num2' ...
    'div -h': 'div' usage: 'div [-s?] num1 ( / % m qr ) num2' ...
    Items in '[]' are optional. One item in '(...)' is required.
    
    Main functions use input format: 'func_name Num1 operator Num2'
    Examples: 'add 2.47 + 3.24'  'mul 3.47 x 5.39' 'div 42.6 / 3.5'
    
    Inputs must be space-separated: 'add 2 + 3' not: 'add 2+3'.
    Operators + - x X are optional, but 'div' requires 1 operator.
    iq does not evaluate expressions like: '( 3 + (4 x 5) )'
    
    Main functions have a scale option: '-s?', where '?' is
    the desired scale,  which must be a positive integer.
    If used, scale must be first parameter: 'mul -s6 3.46  5.83'
    Using '-s0' (zero) truncates answers to integer output.
    
    Used without scaling, 'add' and 'mul' output the full result.
    'add' and 'mul' can work in series: mul 2 x 3 x 252.424 ...
    but truncation is only done after the last calculation.
    'add' accepts mixed signs/operators: 'add 6 -3 1 + -4 - -4',
    but not 'add 3 --2 +-6'.
    
    Main and Comparison functions support Arbitrary Precision.
    Scale values -s? mean Decimal places of fraction precision.
    For operations like powers, logs, roots, or trigonometry
    use the extended version of the calculator 'iq+'.
    "
}

# list all loaded functions
list_funcs() {
    echo " iq  main functions:"$iqmain 
    [ -n "$iqxmain" ] && echo " iq+ main functions: "$iqxmain 
    [ -n "$iqxutil" ] && echo " iq+ util functions: "$iqxutil
    [ -n "$iqtrig" ] && echo " iq  trig functions: "$iqtrig
    [ -n "$iqutil" ] && echo " iq  util functions: "$iqutil
    [ -n "$iqmisc" ] && echo " iq  misc functions: "$iqmisc
    if [ -n "$iqaimain" ] ; then
        echo " iq_ai  activations:"$iqaimain
        echo " iq_ai  derivatives:"$iqaiderivs
        echo " iq_ai experimental:"$iqai_experimental
    fi
}
# help for Interactive Mode
interactive_help() {
echo "          IQ $iqversion - Interactive Mode
    
    In this mode you can use iq interactively. The iq+ and
    iq_trig modules are pre-loaded. You can also load these
    extra IQ modules for extended functionality.
    Loadable modules: iq_misc iq_util iq_ai
    Type 'iqhelp' for full help for 'iq', or 'list' to show functions
    " 
}

# defaults for execution environment
src=${src:-0} # don't change this
# used internally, don't change
defzero='.0'

# allowed functions for execution and interactive modes
iqmain=" add mul div tsst cmp3w round iqhelp "

# Execution block starts here
# If being used as a command-line calculator, execution starts here.
# If iq has been properly 'sourced' into the shell or script, this is ignored
if [ "1" != "$src" ] ; then
    # we don't get here if this file has been sourced
    # since we are going to do '$cmd "$@"' below, we make sure that only our functions
    # can be called, by eliminating the PATH and catching any absolute/relative paths
    # save the old path which may be needed in interactive mode
    old_path=$PATH
    PATH=''
    # prioritize a few friendly, evil or time-sensitive items
    case $1 in do_nothing) do_nothing ; exit 0 ;; # people really in-the-know get priority here
        ''|-h|--help|iqhelp) iqhelp >&2 ; exit ;; # seekers,
        */*) echo " $0: Improper or dangerous input(a path): '$1'"  ; exit 1 ;; # hackers, cats
    esac
    
    # then we vet the commands to only accept our named functions
    # Interactive mode
    case $1 in
        -i) echo "      iq - $iqversion - Interactive Mode" >&2
            echo " Type 'q' or 'quit' to close, 'help' or 'list'" >&2
            echo
            iqallowed="$iqmain"
            shift
            # pre-load iq+ and trig modules
            PATH=$old_path
            [ -f ./iq+_${iqversion}.sh ] && { src=1 . ./iq+_${iqversion}.sh ; iqallowed="$iqallowed $iqxmain $iqxutil " ;}  || src=1 . iq+
            [ -f ./iq_trig_${iqversion}.sh ] && { src=1 . ./iq_trig_${iqversion}.sh  ; iqallowed="$iqallowed $iqtrig " ;} || src=1 . iq_trig.sh
            while : ; do
                read -r fun opts
                case ${fun%_help*} in q|exit|quit) exit 0 ;;
                    help) interactive_help ;; list) list_funcs ;; 
                    cmp3w|tsst) "$fun" $opts ; echo $? ;;
                    load) module=$opts okload='fail'
                        case $module in 
                            #*iq+_*.sh) [ -f $module ] && src=1 . $module ; [ 0 = "$?" ] && okload=iq+ ;; 
                            #iq+) PATH=$old_path src=1 . iq+ ; [ 0 = "$?" ] && okload=iq+ ;;
                            #*iq_trig_*.sh) [ -f $module ] && src=1 . $module ; [ 0 = "$?" ] && okload=trig ;;
                            #trig) PATH=$old_path src=1 . iq_trig.sh ; [ 0 = "$?" ] && okload=trig ;;
                            *iq_ai_*.sh) [ -f $module ] && src=1 . $module ; [ 0 = "$?" ] && okload=ai ;;
                            ai) PATH=$old_path src=1 . iq_ai.sh ; [ 0 = "$?" ] && okload=ai ;;
                            *iq_misc_*.sh) [ -f $module ] && src=1 . $module ; [ 0 = "$?" ] && okload=misc ;;
                            misc) PATH=$old_path src=1 . iq_misc.sh ; [ 0 = "$?" ] && okload=misc ;;
                            *iq_util_*.sh) [ -f $module ] && src=1 . $module ; [ 0 = "$?" ] && okload=util ;;
                            util) PATH=$old_path src=1 . iq_util.sh ; [ 0 = "$?" ] && okload=util ;;
                            
                        esac
                        PATH=''
                        case $okload in
                            fail) echo " error loading $module" ; PATH= ;;
                            #iq+) iqallowed="$iqallowed $iqxmain $iqxutil " ;;
                            #trig) iqallowed="$iqallowed $iqtrig " ;;
                            misc) iqallowed="$iqallowed $iqmisc " ;;
                            util) iqallowed="$iqallowed $iqutil " ;;
                            ai) iqallowed="$iqallowed $iqaimain $iqaiderivs $iqai_experimental " ;;
                        esac
                        [ fail = "$okload"  ] || echo " module '$module' loaded"
                    ;;
                    *)  case "${iqallowed}" in
                            *" ${fun%_help*} "*) "$fun" $opts ;;
                            *)  echo "----> ${0##*/}: Invalid function name:----> $*" >&2 
                            echo "----> Valid functions:$iqallowed " >&2 
                            exit 1 ;;
                        esac
                    ;;
                esac
                #echo
            done
        ;;
    esac
    
    # Normal execution as a program
    # Same vetting as above
    allowed=" add mul div tsst cmp3w round iqhelp list_funcs "
    case "${allowed}" in
        *" ${1%_help*} "*) : ;;
        *)  echo "----> ${0##*/}: Invalid function name, exploit attempt or insult:----> $*" >&2 
            echo "----> Valid functions: $allowed " >&2 
            exit 1 
        ;;
    esac
    cmd=$1 ; shift
    $cmd "$@"
    # exit status so that: 'iq tsst 1111 -gt 1110 ; echo $?' works as expected
    exit $?
fi
### end of code

###                           Directions for use                              ##
# iq is mainly designed to replace external calculators in other shell scripts
# it can also be used as a command-line calculator, or from your shell session.

# To use iq as a command-line calculator, make the file executable with: 'chmod +x iq'
# Then call the program like this: './iq add 23.43578 + 7234.45', if in the same directory as iq.
# Or, put 'iq' in your path, then call it like a normal program: 'iq add 23.43578 + 7234.45'
# Or, you can temporarily add the location of 'iq' to PATH and use it from anywhere:
# PATH=path_to_iq:$PATH iq add 23.43578 + 7234.45

# For use from within your shell session, or in other shell scripts, making
# the file executable and changing the 'shebang' doesn't need to be done.
# For interactive use from your shell session, source the file like this: 
# 'src=1 . ./iq' or 'src=1 . iq' if iq is in PATH
# For use in shell scripts, put the same line near the top of your script.

# Running 'iq -h' will display a short general help message. For help with a specific
# function like 'add', the command 'iq add -h' will show the help for the 'add' function.
# For more detailed information, most functions have useful notes and comments in the 
# function header. Each functions' dependencies are also listed above each function.

# iq and iq+ are tested under these shells: bash zsh posh yash ash(busybox) dash ksh
# Using a shell further to right in the list, will speed execution times.
# Compared to bash, iq+ is ~2.5X faster on dash and ~6X faster on ksh.
# To use iq with a shell other than /bin/sh, change the first line 'shebang' 
# of the file : '#!/bin/sh' to use 'ksh', 'dash', 'ash'(busybox), 'posh', 'yash', 'zsh' or 'bash'.
# If you find other shells which will run this script, please let me know.

### Error Messages
# When Tutorial-mode is not being used, most error-handling is left to the shell and GIGO rules apply
# Here are some possible error messages from the shell itself, and their cause:
# iq: line ?: ? : arithmetic syntax error   #cause--> non-numeric characters in input
# iq: 546: ls: not found      # cause--> user/cat is mis-typing function names, or trying to exploit us
# iq: 82: [: Illegal number: +11/bin/ls00 # cause--> by now cat is furiously trying to get root
# iq: 142: arithmetic expression: division by zero: "1/bin/ls0+100000020+0" # cause--> user...
# iq: 142: arithmetic expression: expecting EOF: "1login0+1000050+0" # cause--> cat tries again... time for a nap

# This project began April 2, 2020
