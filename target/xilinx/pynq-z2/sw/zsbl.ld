OUTPUT_ARCH( "riscv" )
ENTRY( _start )

SECTIONS
{
  /* Must match ZsblBase in friscv_axi_wrap.v */
  . = 0x1000;

  .text : {
    *(.text)
  }

  .data : { *(.data) }
  .bss : { *(.bss) }
}
