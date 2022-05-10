         ;代码清单8-1
         ;文件名：c08_mbr.asm
         ;文件说明：硬盘主引导扇区代码（加载程序） 
         ;创建日期：2011-5-5 18:17
         
         app_lba_start equ 100           ;声明常数（用户程序起始逻辑扇区号）
                                         ;常数的声明不会占用汇编地址
                                    
SECTION mbr align=16 vstart=0x7c00                                     

         ;设置堆栈段和栈指针 
         mov ax,0      
         mov ss,ax
         mov sp,ax
		 ; -- 逻辑段地址 * 16 + 逻辑偏移地址 = 物理地址 ，所以除以16
         mov ax,[cs:phy_base]            ;计算用于加载用户程序的逻辑段地址 
         mov dx,[cs:phy_base+0x02]
         mov bx,16                       ; -- 除以16，即10H
         div bx                          ; -- ax中得到逻辑段地址
         mov ds,ax                       ;令DS和ES指向该段以进行操作
         mov es,ax                        
    
         ;以下读取程序的起始部分 
         xor di,di
         mov si,app_lba_start            ;程序在硬盘上的起始逻辑扇区号 
         xor bx,bx                       ;加载到DS:0x0000处 
         call read_hard_disk_0
      
         ;以下判断整个程序有多大  -- dx:ax 就是用户程序大小
         mov dx,[2]                      ;曾经把dx写成了ds，花了二十分钟排错 
         mov ax,[0]
         mov bx,512                      ;512字节每扇区
         div bx                          ; -- 除以512字节 ，就能得到用户程序占用多少个扇区了
         cmp dx,0                        ; 在凑巧的情况下，用户程序的大小 正好是512的整数倍，做完除法后在寄存器AX中是用户程序实际占用的扇区数,如果dx不为0（有余数）
         jnz @1                          ;未除尽，因此结果比实际扇区数少1 
         dec ax                          ;已经读了一个扇区，扇区总数减1 -- 在前面第27行代码已经调用过一次read_hard_disk_0了
   @1:
         cmp ax,0                        ;考虑实际长度小于等于512个字节的情况 -- 可能小于1个扇区的情况那么ax会等于0
         jz direct                       ; -- ax=0的情况，跳转到direct，意味着只有1个扇区，前面读过了
         
         ;读取剩余的扇区
         push ds                         ;以下要用到并改变DS寄存器 

         mov cx,ax                       ;循环次数（剩余扇区数）
   @2:
         mov ax,ds
         add ax,0x20                     ;得到下一个以512字节为边界的段地址
         mov ds,ax  
                              
         xor bx,bx                       ;每次读时，偏移地址始终为0x0000 
         inc si                          ;下一个逻辑扇区 
         call read_hard_disk_0
         loop @2                         ;循环读，直到读完整个功能程序 

         pop ds                          ;恢复数据段基址到用户程序头部段 
      
         ;计算入口点代码段基址 
   direct:
         mov dx,[0x08]                    ; --用户程序段地址高位
         mov ax,[0x06]                    ; --用户程序段地址低位
         call calc_segment_base
         mov [0x06],ax                   ;回填修正后的入口点代码段基址 
      
         ;开始处理段重定位表
         mov cx,[0x0a]                   ;需要重定位的项目数量
         mov bx,0x0c                     ;重定位表首地址
          
 realloc:
         mov dx,[bx+0x02]                ;32位地址的高16位 
         mov ax,[bx]
         call calc_segment_base
         mov [bx],ax                     ;回填段的基址
         add bx,4                        ;下一个重定位项（每项占4个字节） 
         loop realloc 
      
         jmp far [0x04]                  ;转移到用户程序  
 
;-------------------------------------------------------------------------------
read_hard_disk_0:                        ;从硬盘读取一个逻辑扇区
                                         ;输入：DI:SI=起始逻辑扇区号
                                         ;      DS:BX=目标缓冲区地址
         push ax
         push bx
         push cx
         push dx
      
         mov dx,0x1f2
         mov al,1
         out dx,al                       ;读取的扇区数

         inc dx                          ;0x1f3
         mov ax,si
         out dx,al                       ;LBA地址7~0

         inc dx                          ;0x1f4
         mov al,ah
         out dx,al                       ;LBA地址15~8

         inc dx                          ;0x1f5
         mov ax,di
         out dx,al                       ;LBA地址23~16

         inc dx                          ;0x1f6
         mov al,0xe0                     ;LBA28模式，主盘
         or al,ah                        ;LBA地址27~24 --  al = 11100000  高3位是111 ，第6位是1，表示LBA模式，第4位是0表示主硬盘，见书上图8-11 端口1f6各位的含义
         out dx,al

         inc dx                          ;0x1f7
         mov al,0x20                     ;读命令
         out dx,al

  .waits:                               ; -- 这个子过程主要判断磁盘是否忙完
         in al,dx
         and al,0x88                    ; -- 0x88的二进制是10001000 ，and 表示 第7位和第3位才会可能是1，其他全是0
         cmp al,0x08					; -- 0x08的二进制是1000 ，比较如果是1000就不忙，已准备好
         jnz .waits                      ;不忙，且硬盘已准备好数据传输 

         mov cx,256                      ;总共要读取的字数 -- 猜测因为下面是ax，每次是读2个字节，所以循环256次就可以了
         mov dx,0x1f0
  .readw:
         in ax,dx
         mov [bx],ax
         add bx,2
         loop .readw

         pop dx
         pop cx
         pop bx
         pop ax
      
         ret

;-------------------------------------------------------------------------------
calc_segment_base:                       ;计算16位段地址
                                         ;输入：DX:AX=32位物理地址
                                         ;返回：AX=16位段基地址 
         push dx                          
         
         add ax,[cs:phy_base]            ;-- 低16位
         adc dx,[cs:phy_base+0x02]       ; --高16位,adc带进位加法
         shr ax,4                        ; --右移4位，相当于除以16(10H)，空出ax的高4位，是为了后面得到逻辑段地址
         ror dx,4                        ; -- ror(Rotate Right)指令循环右移，右边的4位(从最右边开始)依次移动到左边
         and dx,0xf000                   ; -- 0xf000二进制1111000000000000，只保有效留高4位，其余位清除置为0，因为理论上只有20位是有效
         or ax,dx                        ; -- or指令合并 ax和dx中的值
         
         pop dx
         
         ret

;-------------------------------------------------------------------------------
         phy_base dd 0x10000             ;用户程序被加载的物理起始地址
         
 times 510-($-$$) db 0
                  db 0x55,0xaa