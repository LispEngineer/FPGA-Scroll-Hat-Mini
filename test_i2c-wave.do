onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /test_i2c/clk
add wave -noupdate /test_i2c/reset
add wave -noupdate -divider {Controller Out}
add wave -noupdate /test_i2c/scl_o
add wave -noupdate /test_i2c/scl_e
add wave -noupdate /test_i2c/sda_o_c
add wave -noupdate /test_i2c/sda_e_c
add wave -noupdate -divider {Controller In}
add wave -noupdate /test_i2c/sda_i_c
add wave -noupdate /test_i2c/i2c_ack
add wave -noupdate -divider {I2C Controller}
add wave -noupdate /test_i2c/i2c_activate
add wave -noupdate /test_i2c/i2c_busy
add wave -noupdate /test_i2c/i2c_start
add wave -noupdate /test_i2c/i2c_stop
add wave -noupdate /test_i2c/i2c_abort
add wave -noupdate /test_i2c/i2c_success
add wave -noupdate {/test_i2c/dut/k_address[0]}
add wave -noupdate /test_i2c/dut/k_read_two
add wave -noupdate -divider {I2C Target}
add wave -noupdate /test_i2c/sda_i_t
add wave -noupdate /test_i2c/sda_o_t
add wave -noupdate /test_i2c/sda_e_t
add wave -noupdate /test_i2c/test_target/sda_change
add wave -noupdate /test_i2c/start_seen
add wave -noupdate /test_i2c/stop_seen
add wave -noupdate /test_i2c/in_transaction
add wave -noupdate -divider {Target Internals}
add wave -noupdate /test_i2c/test_target/state
add wave -noupdate /test_i2c/test_target/bit_cnt
add wave -noupdate /test_i2c/test_target/address_seen
add wave -noupdate /test_i2c/test_target/is_us
add wave -noupdate /test_i2c/test_target/is_write
add wave -noupdate -divider {Test Script}
add wave -noupdate /test_i2c/test_script/rom_step
add wave -noupdate /test_i2c/test_script/active
add wave -noupdate /test_i2c/test_script/done
add wave -noupdate /test_i2c/test_script/busy_seen
add wave -noupdate /test_i2c/test_script/setup_state
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {17790000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 121
configure wave -valuecolwidth 48
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {6238105 ps} {25551876 ps}
