quit -sim

if [file exists audio_fft] { vdel -all -lib audio_fft }
vlib audio_fft
vmap audio_fft audio_fft
vmap work audio_fft

vcom -93 -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/auk_dspip_text_pkg.vhd"
vcom -93 -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/auk_dspip_math_pkg.vhd"
vcom -93 -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/auk_dspip_lib_pkg.vhd"
vcom -93 -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/auk_dspip_avalon_streaming_controller.vhd"
vcom -93 -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/auk_dspip_avalon_streaming_sink.vhd"
vcom -93 -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/auk_dspip_avalon_streaming_source.vhd"
vcom -93 -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/auk_dspip_roundsat.vhd"

vcom -93 -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/mentor/auk_fft_pkg.vhd"
vcom -93 -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/mentor/fft_pack.vhd"
vcom -93 -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/mentor/*.vhd"

vlog -sv -work audio_fft "../rtl/fft/audio_fft/simulation/submodules/audio_fft_fft_ii_0.sv"
vlog -work audio_fft "../rtl/fft/audio_fft/simulation/audio_fft.v"

vlib work_tb
vmap work work_tb

vlog -sv "../rtl/core/amplitude_calc.sv"
vlog -sv "../rtl/core/ram_writer.sv"
vlog -sv "tb_dsp_pipeline.sv"

file copy -force "../rtl/fft/audio_fft/simulation/submodules/audio_fft_fft_ii_0_1n1024cos.hex" .
file copy -force "../rtl/fft/audio_fft/simulation/submodules/audio_fft_fft_ii_0_1n1024sin.hex" .
file copy -force "../rtl/fft/audio_fft/simulation/submodules/audio_fft_fft_ii_0_2n1024cos.hex" .
file copy -force "../rtl/fft/audio_fft/simulation/submodules/audio_fft_fft_ii_0_2n1024sin.hex" .
file copy -force "../rtl/fft/audio_fft/simulation/submodules/audio_fft_fft_ii_0_3n1024cos.hex" .
file copy -force "../rtl/fft/audio_fft/simulation/submodules/audio_fft_fft_ii_0_3n1024sin.hex" .

vsim -voptargs="+acc" -t 1ps -L work_tb -L audio_fft -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver work_tb.tb_dsp_pipeline

add wave -r /*

run -all