#!/bin/sh

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

while : ; do  
    case $1 in 
        -a*) Activator1=${1#-a*} ; shift ;;
        -d) debug=1 ; shift ;;
        #-e*) epochs=${1#-e*} ; shift ;; 
        -if*) input_file=${1#-if*} ; shift ;;
        #-of*) output_file=${1#-of*} ; shift ;;
        #-l*) learn_rate=${1#-l*} ; shift ;;
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
epochs=${epochs:-1} 
input_file=${input_file:-./mm2x2x2_weights.sh}
# if no output_file is specified, output will not be written, only shown
#output_file=${output_file:-$input_file}
learn_rate=${learn_rate:-1}
scale=${scale:-8}
debug=${debug:-0}
target1=${target1:-1}
target2=${target2:-1}

# initialize the layers
#lab1=X idx1=1 dim1=3
#lab2=H idx2=1 dim2=4
#lab3=Z idx3=1 dim3=2
#. ./H3x4x2_weights.sh
. $input_file

# begin feed-forward
echo "calculating $lab2 nodes: $lab2""_wts * $lab1 inputs"
# iterate down the $lab2 node column
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
    # set the variable for the value of this $lab2 node
    # H1=$H1 H2=$H2
    eval "$lab2$idx2=$hidsum"
    # go to next H node
    idx2=$((idx2+1))
done
idx2=1
# outputs H1, H2, etc.
idx3=1
echo "calculating $lab3 nodes: $lab3""_wts * $lab2 nodes"
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
    #eval "output$idx3=$sum"
    # go to next Z? node
    idx3=$((idx3+1))
done
# outputs output1 output2
idx3=1

# calculate the error for each ouput
echo "output sums, errors"
echo output1=$output1
E1=$( add $target1 - $output1 )
echo output2=$output2
E2=$( add $target2 - $output2 )

E1_sq=$( mul -s$scale 0.5 x $E1 x $E1 )
E2_sq=$( mul -s$scale 0.5 x $E2 x $E2 ) 

echo E1=$E1
echo E2=$E2
Etotal=$( add $E1_sq + $E2_sq )
echo Etotal=$Etotal
echo 

echo "output1  target1   error1"
echo "$output1 $target1 $E1"
echo "output2  target2   error2"
echo "$output2 $target2 $E2"
echo total_error=$Etotal
soft2maxbin() { case $1 in -s*) scale=${1#-s*} ; shift ;; *) scale=$defprec ;; esac
    a=$1 b=$2 c=$3 
    a_sqr=$( mul -s$scale $a x $a )
    b_sqr=$( mul -s$scale $b x $b )
    sum_of_squares=$( add $a_sqr + $b_sqr )
    a_out=$( div -s$scale $a_sqr / $sum_of_squares )
    b_out=$( div -s$scale $b_sqr / $sum_of_squares )
    echo $a_out $b_out
} ## softmax2


percent=$( mul -s$scale 100 x $(add 1 - $Etotal ) )
echo "$percent % accuracy"

soft2maxbin $E1 $E2

