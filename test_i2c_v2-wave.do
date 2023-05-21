onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /test_i2c_v2/reset
add wave -noupdate /test_i2c_v2/clk
add wave -noupdate -divider {Controller Out}
add wave -noupdate /test_i2c_v2/scl_o
add wave -noupdate /test_i2c_v2/sda_e_c
add wave -noupdate /test_i2c_v2/sda_o_c
add wave -noupdate -divider {Controller In}
add wave -noupdate /test_i2c_v2/sda_i_c
add wave -noupdate -divider {I2C Controller}
add wave -noupdate /test_i2c_v2/i2c_ack
add wave -noupdate /test_i2c_v2/i2c_activate
add wave -noupdate /test_i2c_v2/i2c_busy
add wave -noupdate /test_i2c_v2/i2c_start
add wave -noupdate /test_i2c_v2/i2c_stop
add wave -noupdate /test_i2c_v2/i2c_abort
add wave -noupdate /test_i2c_v2/i2c_success
add wave -noupdate /test_i2c_v2/i2c_address
add wave -noupdate /test_i2c_v2/i2c_readnotwrite
add wave -noupdate /test_i2c_v2/i2c_read_count
add wave -noupdate /test_i2c_v2/i2c_read
add wave -noupdate /test_i2c_v2/i2c_send_count
add wave -noupdate /test_i2c_v2/i2c_send
add wave -noupdate -divider {Controller Internals}
add wave -noupdate /test_i2c_v2/dut/state
add wave -noupdate /test_i2c_v2/dut/step
add wave -noupdate /test_i2c_v2/dut/byte_step
add wave -noupdate /test_i2c_v2/dut/byte_idx
add wave -noupdate /test_i2c_v2/dut/send_pos
add wave -noupdate /test_i2c_v2/dut/last_send_pos
add wave -noupdate /test_i2c_v2/dut/read_pos
add wave -noupdate /test_i2c_v2/dut/last_read_pos
add wave -noupdate /test_i2c_v2/dut/data_accum
add wave -noupdate -divider {I2C Target}
add wave -noupdate /test_i2c_v2/sda_i_t
add wave -noupdate /test_i2c_v2/sda_e_t
add wave -noupdate /test_i2c_v2/sda_o_t
add wave -noupdate /test_i2c_v2/test_target/sda_change
add wave -noupdate /test_i2c_v2/test_target/start_seen
add wave -noupdate /test_i2c_v2/test_target/stop_seen
add wave -noupdate /test_i2c_v2/test_target/in_transaction
add wave -noupdate -divider {Target Internals}
add wave -noupdate /test_i2c_v2/test_target/state
add wave -noupdate /test_i2c_v2/test_target/bit_cnt
add wave -noupdate /test_i2c_v2/test_target/address_seen
add wave -noupdate /test_i2c_v2/test_target/is_us
add wave -noupdate /test_i2c_v2/test_target/is_write
add wave -noupdate -divider {Test Script}
add wave -noupdate /test_i2c_v2/test_script/rom_step
add wave -noupdate /test_i2c_v2/test_script/active
add wave -noupdate /test_i2c_v2/test_script/done
add wave -noupdate /test_i2c_v2/test_script/busy_seen
add wave -noupdate /test_i2c_v2/test_script/setup_state
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1610000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 129
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
WaveRestoreZoom {605872 ps} {12730890 ps}
