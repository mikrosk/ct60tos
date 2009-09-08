echo on
..\gpasm -DPIC18F258 -w1 eiffel.asm -I ..\header -o eif18can.hex > out18can.txt
..\gpasm -DPIC18F242 -w1 eiffel.asm -I ..\header -o eiffel18.hex > out18.txt
..\gpasm -DPIC18F242CF -w1 eiffel.asm -I ..\header -o eiff18cf.hex > out18cf.txt
..\gpasm -DPIC16F876 -w1 eiffel.asm -I ..\header -o eiffel16.hex > out16.txt
