#!/bin/sh

# hoorah! 3 May 2023 - a real neural-network in shell
# this is a working implementation of a text-book example found here:
# https://mattmazur.com/2015/03/17/a-step-by-step-backpropagation-example/
# verified using the authors from-scratch python example here:
# https://github.com/mattm/simple-neural-network/blob/master/neural-network.py

src=1 . ./iq_1.79.sh

sigmoid_tanh() { case $1 in -s*) scale=${1#-s*} ; shift ;; *) scale=$defprec ;; esac
    x=$1 
    x_divided=$( mul -s$scale $x 0.5 )
    tanh_beta=$( tanh_pade -s$scale $x_divided )
    tanh_beta_plus_1=$( add $tanh_beta 1 )
    div -s$scale $tanh_beta_plus_1 / 2
} ## sigmoid
# We use a Pade approximation for tanh
tanh_pade() { case $1 in -s*) thpscale=${1#-s*} ; shift ;; *) thpscale=$defprec ;;esac
    x=$1
    case $x in '-'*) tanh_neg='-' x=${x#*-} ;; *) tanh_neg= ;; esac
    x2=$( mul -s$thpscale $x $x )
    x4=$( mul -s$thpscale $x2 $x2 )
    x6=$( mul -s$thpscale $x4 $x2 )
    # nom
    a=$( mul -s$thpscale 1260 $x2 )
    b=$( mul -s$thpscale 21 $x4 )
    d=$( add 10395 + $a + $b  )
    e=$( mul -s$thpscale $x $d )
    # denom
    f=$( mul -s$thpscale 4725 $x2 )
    g=$( mul -s$thpscale 210 $x4 )
    j=$( add -s$thpscale  10395 + $f + $g + $x6 )
    
    r_tanh=$( div -s$thpscale $e / $j )
    echo $tanh_neg$r_tanh
} ## tanh_pade

# sigmoid'@(x) = (@*sig@(x)) * (1 - sig@(x))
d1_have_sigmoid() {  case $1 in -s*) scale=${1#-s*} ; shift ;; *) scale=$defprec ;; esac
    sig_x=$1
    # we have the sigmoid already
    #sig_x=$( sigmoid_real -s$scale $x )
    #sig_x=$( sigmoid_tanh -s$scale $x )    # faster
    one_less_sig_x=$( add 1 - $sig_x )
    mul -s$scale $sig_x $one_less_sig_x
} ##

while : ; do  
    case $1 in 
        -a*) Activator1=${1#-a*} ; shift ;;
        -d) debug=1 ; shift ;;
        -q) quiet=1 ; shift ;;
        -e*) epochs=${1#-e*} ; shift ;; 
        -if*) input_file=${1#-if*} ; shift ;;
        -of*) output_file=${1#-of*} ; shift ;;
        -l*) learn_rate=${1#-l*} ; shift ;;
        -s*) scale=${1#-s*} ; shift ;;
        *) break ;; 
    esac
done

input1=$1
input2=$2

target1=$3
target2=$4

#Activator1=${Activator1:-tanh_pade}
Activator1=${Activator1:-sigmoid_tanh}
Derivativ1=${Derivativ1:-d1_have_sigmoid}

epochs=${epochs:-1} 
input_file=${input_file:-./mm2x2x2_weights.sh}
# if no output_file is specified, output will not be written, only shown
#output_file=${output_file:-$input_file}
learn_rate=${learn_rate:-0.5}
scale=${scale:-8}
debug=${debug:-0}
quiet=${quiet-0}
target1=${target1:-1}
target2=${target2:-1}

# initializing the layers and biases
# is done in the weights file
#lab1=X idx1=1 dim1=3
#lab2=H idx2=1 dim2=4
#lab3=Z idx3=1 dim3=2
#. ./H3x4x2_weights.sh
. $input_file

#Hbias=$b1
#Zbias=$b2

# the big training loop
loops=0
while [ $loops -lt $epochs ] ;do

[ 0 = "$quiet" ] && echo "calculating $lab2 nodes: $lab2""_wts * $lab1 inputs"
#for node_wts in "$H1_wts" "$H2_wts" "$H3_wts" "$H4_wts"  ; do
for node_wts in "$H1_wts" "$H2_wts" ; do
    # iterate down the $lab2 column, calculating a
    # normalized Sum Of Products of weights * inputs
    # as the output for each $lab2 node
    sum=$Hbias
    for weight in $node_wts ; do
        prod=0
        input=$(eval echo "\$input${idx1}")
        # echo wx "$weight x $input"
        # multiply weight x input
        prod=$( mul $weight x $input )
        # add this product to the sum
        sum=$( add $sum $prod)
        # next weight
        idx1=$((idx1+1))
    done
    idx1=1
    # normalize the Sum Of Products
    hidsum=$( $Activator1 -s$scale $sum )
    # set the node variable for the value of this $lab2 node
    eval "$lab2$idx2=$hidsum"
    # go to next H node
    idx2=$((idx2+1))
done
idx2=1
# outputs H1, H2, etc.
#echo H1=$H1
#echo H2=$H2

idx3=1
[ 0 = "$quiet" ] && echo "calculating $lab3 nodes: $lab3""_wts * $lab2 nodes"
for node_wts in "$Z1_wts" "$Z2_wts"  ; do
    sum=$Zbias
    # Sum Of Products: Z output weights x Hidden node outputs
    for weight in $node_wts ; do
        prod=0
        # get value of each node from previous layer
        H_node=$( eval echo "\$$lab2$idx2")
        # product of $lab2 node value * each weight to $lab3 node
        prod=$( mul -s$scale $H_node x $weight )
        #echo Hw $H_node x $weight
        # add the product to the sum
        sum=$( add $sum $prod )
        idx2=$((idx2+1))
    done
    idx2=1
    # normalize the Sum Of Products
    # set the variable for the output of this output Z node
    eval "output$idx3=$( $Activator1 -s$scale $sum)"
    # go to next Z? node
    idx3=$((idx3+1))
done
# outputs output1 output2
idx3=1

# calculate the error for each ouput
[ 0 = "$quiet" ] && echo "targets, outputs, errors"
#echo output1=$output1
E1=$( add $target1 - $output1 )
#echo E1=$E1
[ 0 = "$quiet" ] && echo output1 $target1 $output1 $E1

#echo output2=$output2
E2=$( add $target2 - $output2 )
#echo E2=$E2
[ 0 = "$quiet" ] && echo output2 $target2 $output2 $E2

E1_sq=$( mul -s$scale 0.5 x $E1 x $E1 )
E2_sq=$( mul -s$scale 0.5 x $E2 x $E2 ) 

Etotal=$( add $E1_sq + $E2_sq )
[ 0 = "$quiet" ] && echo
echo Etotal=$Etotal
[ 0 = "$quiet" ] && echo 


# training
# calculate deltas for weights of each Z node
# delta = output * (1st deriv of output) * error
#echo "calculating Z node deltas and updating weights"
for node_wts in "$Z1_wts" "$Z2_wts"  ; do
    # get the deltaout
    [ 0 = "$quiet" ] && echo "calculating Z${idx3} node deltas and updating weights"
    output=$( eval echo "\$output${idx3}" )
    [ 1 = "$debug" ] && echo output${idx3}=$output
    target=$( eval echo "\$target${idx3}" )
    [ 1 = "$debug" ] && echo target=$target
    #prederr=$( add $target - $sum )
    prederr=$( add  $output - $target )
    # Etotal error change wrt the output(output?
    [ 1 = "$debug" ] && echo prederr=$prederr
    eval "prederr${idx3}=${prederr}"
    # 1st deriv of output
    case $Activator1 in 
        sigmoid_tanh) deltaout=$( d1_have_sigmoid -s$scale $output ) ;;
        tanh_pade) deltaout=$( mul -s$scale $output x $(add 1 - $(mul -s$scale $output x $output))  ) ;;
    esac
    [ 1 = "$debug" ] && echo deltaout=$deltaout
    eval "deltaout${idx3}=${deltaout}"
    [ 1 = "$debug" ] && echo
    new_wts=''
    for weight in $node_wts ; do
        H_node=$( eval echo "\$${lab2}${idx2}"  )
        [ 1 = "$debug" ] && echo H-node ${lab2}${idx2} $H_node
        delta_wt=$( mul -s$scale ${prederr} $deltaout $H_node )
        [ 1 = "$debug" ] && echo "prederr   x  deltaout  x   H_node"
        [ 1 = "$debug" ] && echo ${prederr} x $deltaout x $H_node
        [ 1 = "$debug" ] && echo delta_wt=$delta_wt
        [ 1 = "$debug" ] && echo
        # calculate the new weight and add to the array
        new_wt=$( add $weight - $(mul -s$scale $learn_rate x $delta_wt)  )
        new_wts="$new_wts""$new_wt "
        idx2=$((idx2+1))
    done
    idx2=1
    # keep the original values for H-nodes
    #[ 1 = "$debug" ] && echo old_wts_Z$idx3="'$node_wts'"
    [ 0 = "$quiet" ] && echo old_wts_Z$idx3="'$node_wts'"
    eval "old_wts_Z$idx3='$node_wts'"
    
    label=${lab3}${idx3}'_wts'
    # set the variable holding the new weights
    eval "$label='$new_wts'"
    #[ 1 = "$debug" ] && echo new_wts_Z$idx3="'$new_wts'"
    [ 0 = "$quiet" ] &&  echo new_wts_Z$idx3="'$new_wts'"
    [ 1 = "$debug" ] && echo
    idx3=$((idx3+1))
done
idx3=1

# re-orient the old Z_wts to their H nodes
#cnt=1
idx2=1
while [ $idx2 -le $dim2 ] ; do
    # read the old rows column-by-column
    z1=${old_wts_Z1%%' '*}
    z2=${old_wts_Z2%%' '*}
    # munch the rows
    old_wts_Z1=${old_wts_Z1#*' '}
    old_wts_Z2=${old_wts_Z2#*' '}
    # add the current values to the new array
    old_HZ_wts="$old_HZ_wts""$z1 $z2 "
    eval "old_wts_ZH${idx2}='$old_HZ_wts'"
    old_HZ_wts=''
    idx2=$((idx2+1))
done
idx2=1

[ 0 = "$quiet" ] && echo
idx1=1
idx2=1
idx3=1
# calculate H hidden layer node deltas and update their weights
#for node_wts in "$H1_wts" "$H2_wts" "$H3_wts" "$H4_wts" ; do
for node_wts in "$H1_wts" "$H2_wts" ; do
    [ 0 = "$quiet" ] && echo "calculating H${idx2} node deltas and updating weights"
    
    new_wts=''
    for this_weight in $node_wts ; do
        #echo loop2------------------------
        old_ZH_wts=$( eval echo "\$old_wts_ZH${idx2}" )
        [ 1 = "$debug" ] && echo old_ZH_wts=$old_ZH_wts
        #sum=$Zbias
        sum=0
        [ 1 = "$debug" ] && echo sum=$sum
        for weight in $old_ZH_wts ; do
        
                prederr=$( eval echo "\$prederr${idx3}" )
                [ 1 = "$debug" ] && echo prederr${idx3}=$prederr
        
                deltaout=$( eval echo "\$deltaout${idx3}" )
                [ 1 = "$debug" ] && echo deltaout${idx3}=$deltaout
        
                delta_part=$( mul -s$scale $prederr $deltaout )
                [ 1 = "$debug" ] && echo delta_part=$delta_part
        
                [ 1 = "$debug" ] &&  echo "weight   x    delta_part"
                [ 1 = "$debug" ] && echo $weight x $delta_part 
                # E1/outH1
                prod=$( mul -s$scale $weight x $delta_part )
                [ 1 = "$debug" ] && echo prod=$prod
        
                sum=$( add $sum + $prod )
                [ 1 = "$debug" ] && echo sum=$sum
                idx3=$((idx3+1))
                #sleep 1
                [ 1 = "$debug" ] && echo
        done
        idx3=1
    
        H_node=$( eval echo "\$${lab2}${idx2}" )
        [ 1 = "$debug" ] && echo H_node=$H_node
        case $Activator1 in 
            sigmoid_tanh) pd_outH_pd_netH=$( d1_have_sigmoid -s$scale $H_node ) ;;
            tanh_pade) pd_outH_pd_netH=$( mul -s$scale $H_node x $(add 1 - $(mul -s$scale $H_node x $H_node))  ) ;;
        esac
        [ 1 = "$debug" ] && echo pd_outH${idx2}_pd_netH${idx2}
        [ 1 = "$debug" ] && echo $pd_outH_pd_netH
    
        # sum x pd_outH_pd_netH x this_input
        input=$( eval echo "\$input${idx1}" )
        #echo input=$input
        pd_Etotal_pd_this_weight=$( mul -s$scale $sum x $pd_outH_pd_netH x $input)
        #pd_Etotal_pd_this_weight=$( mul -s$scale $sum x $pd_outH_pd_netH x $input1)
    
        [ 1 = "$debug" ] && echo pd_Etotal_pd_this_weight=$pd_Etotal_pd_this_weight
        new_wt=$( add $this_weight - $( mul -s$scale $learn_rate x $pd_Etotal_pd_this_weight ) )
        [ 1 = "$debug" ] && echo new_wt=$new_wt
        new_wts="$new_wts""$new_wt "
        [ 1 = "$debug" ] && echo
        # assign the new weights to the node label
        label="${lab2}${idx2}_wts"
        eval "$label='${new_wts}'"
        idx1=$((idx1+1))
    done
    idx1=1
    [ 0 = "$quiet" ] && echo old_wts_H$idx2="'$node_wts'"
    [ 0 = "$quiet" ] && echo new_wts_H$idx2="'$new_wts'"
    
    idx2=$((idx2+1))
done
idx2=1
[ 0 = "$quiet" ] && echo xxxxxxxxxxxxxxxxxxxxxxxxgoing aaround
loops=$((loops+1))
done

if [ -n "$output_file" ] ; then
    echo output_file = $output_file
      
    echo lab1=$lab1 idx1=$idx1 dim1=$dim1 >$output_file 
    echo lab2=$lab2 idx2=$idx2 dim2=$dim2 >>$output_file 
    echo lab3=$lab3 idx3=$idx3 dim3=$dim3 >>$output_file
    echo Hbias=$Hbias >>$output_file
    echo "#  i1/w1/h1  i1/w2/h2" >>$output_file
    echo H1_wts="'$H1_wts'" >>$output_file
    echo "#  i2/w3/h1  i2/w4/h2" >>$output_file
    echo H2_wts="'$H2_wts'" >>$output_file
    echo Zbias=$Zbias >>$output_file
    echo "#  h1/W5/o1  h2/W6/o1" >>$output_file
    echo Z1_wts="'$Z1_wts'" >>$output_file
    echo "#  h1/W7/o2  h2/W8/o2" >>$output_file
    echo Z2_wts="'$Z2_wts'" >>$output_file
else
    echo "Not writing ouput"
fi

