         ;代码清单8-2
         ;文件名：c08.asm
         ;文件说明：用户程序 
         ;创建日期：2011-5-5 18:17
         
;===============================================================================
SECTION header vstart=0                     ;定义用户程序头部段 
    program_length  dd program_end          ;程序总长度[0x00]
    
    ;用户程序入口点
    code_entry      dw start                ;偏移地址[0x04]
                    dd section.code_1.start ;段地址[0x06] 
    
    realloc_tbl_len dw (header_end-code_1_segment)/4
                                            ;段重定位表项个数[0x0a] -- 计算有多少个段重定位表项 ，因为每个表项是4个字节， (结束-开始) / 4 = 有多少个段重定位表
    
    ;段重定位表           
    code_1_segment  dd section.code_1.start ;[0x0c]
    code_2_segment  dd section.code_2.start ;[0x10]
    data_1_segment  dd section.data_1.start ;[0x14]
    data_2_segment  dd section.data_2.start ;[0x18]
    stack_segment   dd section.stack.start  ;[0x1c]
    
    header_end:                
    
;===============================================================================
SECTION code_1 align=16 vstart=0         ;定义代码段1（16字节对齐） 
put_string:                              ;显示串(0结尾)。
                                         ;输入：DS:BX=串地址
         mov cl,[bx]
         or cl,cl                        ;cl=0 ?
         jz .exit                        ;是的，返回主程序 
         call put_char
         inc bx                          ;下一个字符 
         jmp put_string

   .exit:
         ret

;-------------------------------------------------------------------------------
put_char:                                ;显示一个字符
                                         ;输入：cl=字符ascii
         push ax
         push bx
         push cx
         push dx
         push ds
         push es

         ;以下取当前光标位置
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         mov dx,0x3d5
         in al,dx                        ;高8位 
         mov ah,al

         mov dx,0x3d4
         mov al,0x0f
         out dx,al
         mov dx,0x3d5
         in al,dx                        ;低8位 
         mov bx,ax                       ;BX=代表光标位置的16位数

         cmp cl,0x0d                     ;回车符？- 换行表示是当前行的首个光标
         jnz .put_0a                     ;不是。看看是不是换行等字符 
         mov ax,bx                       ;此句略显多余，但去掉后还得改书，麻烦 
         mov bl,80  ; -- 如果是回车符0x0d，那么，应将光标移动到当前行的行首。
         div bl    ;--每行有80 个字符，那么，用当前光标位置除以80，余数不要，就可以得到当前行的行号。
         mul bl      ;--接着，再乘以80，就是当前行行首的光标数值
         mov bx,ax
         jmp .set_cursor

 .put_0a:
         cmp cl,0x0a                     ;换行符？
         jnz .put_other                  ;不是，那就正常显示字符 
         add bx,80                       ; -- 如果是，光标往下挪1行，就加80
         jmp .roll_screen

 .put_other:                             ;正常显示字符
         mov ax,0xb800
         mov es,ax
         shl bx,1         ; -- 二进制左移1位相当于*2 ,bx作为偏移地址
         mov [es:bx],cl   ; -- mov [es:bx],cl 等同于 mov es:[bx],cl 

         ;以下将光标位置推进一个字符
         shr bx,1        ; -- 二进制右移1位相当于除以2 ，bx作为偏移地址
         add bx,1        ;+1 恢复光标位置

 .roll_screen:  ; --  滚屏实质上就是将屏幕上第2～25 行的内容整体往上提 一行，最后用黑底白字的空白字符填充第25行
         cmp bx,2000                     ;光标超出屏幕？滚屏
         jl .set_cursor

         mov ax,0xb800
         mov ds,ax
         mov es,ax
         cld             ;-- cld 表示正向复制
         mov si,0xa0    ;--屏幕第2 行 第1 列的位置 ，从这个位置开始
         mov di,0x00    ; -- 屏幕第1 行 第1 列的位置 ，复制数据的目标区域从这个位置开始
         mov cx,1920   ; -- 要传输的字节
         rep movsw
         mov bx,3840                     ;清除屏幕最底一行
         mov cx,80
 .cls:
         mov word[es:bx],0x0720  ; -- 使用黑底白字的空白字符循环写入这一行
         add bx,2
         loop .cls

         mov bx,1920

 .set_cursor:    ;-- 将寄存器BX中的高8位和低8 位通过数据段口0x3d5 写入它们，然后恢复寄存器，最后返回
         mov dx,0x3d4
         mov al,0x0e
         out dx,al
         mov dx,0x3d5
         mov al,bh
         out dx,al
         mov dx,0x3d4
         mov al,0x0f
         out dx,al
         mov dx,0x3d5
         mov al,bl
         out dx,al

         pop es
         pop ds
         pop dx
         pop cx
         pop bx
         pop ax

         ret

;-------------------------------------------------------------------------------
  start:
         ;初始执行时，DS和ES指向用户程序头部段  -- 进入用户程序后，初始化用户程序自己的栈段、数据段
         mov ax,ds:[stack_segment]           ;设置到用户程序自己的堆栈 
         mov ss,ax
         mov sp,stack_end
         
         mov ax,[data_1_segment]          ;设置到用户程序自己的数据段
         mov ds,ax

         mov bx,msg0
         call put_string                  ;显示第一段信息 

         push word [es:code_2_segment]
         mov ax,begin
         push ax                          ;可以直接push begin,80386+
         
         retf                             ;转移到代码段2执行  -- 使用retf模拟调用其他代码段
         
  continue:
         mov ax,[es:data_2_segment]       ;段寄存器DS切换到数据段2 
         mov ds,ax
         
         mov bx,msg1
         call put_string                  ;显示第二段信息 

         jmp $ 

;===============================================================================
SECTION code_2 align=16 vstart=0          ;定义代码段2（16字节对齐）

  begin:
         push word [es:code_1_segment]
         mov ax,continue
         push ax                          ;可以直接push continue,80386+
         
         retf                             ;转移到代码段1接着执行 
         
;===============================================================================
SECTION data_1 align=16 vstart=0
      ; -- 0x0d 是回车	  0x0a是换行
    msg0 db '  This is NASM - the famous Netwide Assembler. '
         db 'Back at SourceForge and in intensive development! '
         db 'Get the current versions from http://www.nasm.us/.'
         db 0x0d,0x0a,0x0d,0x0a
         db '  Example code for calculate 1+2+...+1000:',0x0d,0x0a,0x0d,0x0a
         db '     xor dx,dx',0x0d,0x0a
         db '     xor ax,ax',0x0d,0x0a
         db '     xor cx,cx',0x0d,0x0a
         db '  @@:',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     add ax,cx',0x0d,0x0a
         db '     adc dx,0',0x0d,0x0a
         db '     inc cx',0x0d,0x0a
         db '     cmp cx,1000',0x0d,0x0a
         db '     jle @@',0x0d,0x0a
         db '     ... ...(Some other codes)',0x0d,0x0a,0x0d,0x0a
         db 0

;===============================================================================
SECTION data_2 align=16 vstart=0

    msg1 db '  The above contents is written by LeeChung. '
         db '2011-05-06'
         db 0

;===============================================================================
SECTION stack align=16 vstart=0
           
         resb 256 ;-- 伪指令resb（REServe Byte）的意思是从当前位置开始，保留指定 数量的字节，但不初始化它们的值

stack_end:  

;===============================================================================
SECTION trail align=16
program_end: