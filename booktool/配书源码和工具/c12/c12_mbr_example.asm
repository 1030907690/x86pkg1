    ;代码清单12-1
    ;文件名：ex12-1.asm
    ;文件说明：硬盘主引导扇区代码  参考 https://www.jianshu.com/p/34c0d3e350c3  https://blog.csdn.net/longintchar/article/details/50878960
    ;创建日期：16:23 2018/5/30

;---------------------------------------------------------------    
;定义常量
;---------------------------------------------------------------    
    MEMORY_START equ 0x100000           ;要检测的内存起始地址
    MEMORY_END   equ 0x500000           ;要检测的内存结束地址
    MEMORY_SIZE  equ (MEMORY_END-MEMORY_START)/4    ;以双字位单元
;---------------------------------------------------------------    
    
    ;设置堆栈段和栈指针
    mov eax,cs
    mov ss,eax
    mov sp,0x7c00
    
    ;计算GDT所在的逻辑段地址
    mov eax,[cs:pdgt+0x7c00+0x02]   ;GDT的32位线性基地址
    xor edx,edx
    mov ebx,16
    div ebx                         ;分解成16位逻辑地址
    
    mov ds,eax          ;令DS指向该段以进行操作：EAX低16位有效 DS=0x7e00
    mov ebx,edx         ;段内起始偏移地址：EDX EBX低16位有效 ebx=0x0000
    
    ;创建0#描述符,它是空描述符,这是处理器的要求
    mov dword [ebx+0x00],0x00000000
    mov dword [ebx+0x04],0x00000000
    
    ;创建1#描述符，这是一个数据段，对应0~4GB的线性地址空间
    mov dword [ebx+0x08],0x0000ffff     ;段基地址0x00000000
    mov dword [ebx+0x0c],0x00cf9200
    
    ;创建2#描述符，这是一个只执行的代码段
    mov dword [ebx+0x10],0x7c0001ff     ;段基地址0x00007C00
    mov dword [ebx+0x14],0x00409800
    
    ;创建3#描述符，这是上面代码段的别名
    mov dword [ebx+0x18],0x7c0001ff     ;段基地址0x00007C00
    mov dword [ebx+0x1c],0x00409200
    
    ;创建4#描述符，这是栈段
    mov dword [ebx+0x20],0x7c00fffe     ;段基地址0x00007C00
    mov dword [ebx+0x24],0x00cf9600
    
    ;初始化描述符寄存器GDTR
    mov word [cs:pdgt+0x7c00],39        ;5*8-1=39
    lgdt [cs:pdgt+0x7c00]
    
    in al,0x92                          ;南桥芯片的端口
    or al,0000_0010B
    out 0x92,al                         ;打开A20
    
    cli
    
    mov eax,cr0
    or eax,1
    mov cr0,eax                         ;设置PE位
    
    ;以下进入保护模式... ...
    jmp dword 0x0010:flush
    
    [bits 32]
flush:
    mov eax,0x0018      ;索引号3#
    mov ds,eax      
    
    mov eax,0x0008      ;索引号1#
    mov es,eax
    mov fs,eax
    mov gs,eax
    
    mov eax,0x0020      ;索引号4#
    mov ss,eax
    xor esp,esp         ;ESP=0
    
    mov dword [es:0x0b8000],0x072e0750  ;'P.'
    mov dword [es:0x0b8004],0x072e074d  ;'M.'
    mov dword [es:0x0b8008],0x07200720  ;'  '
    mov dword [es:0x0b800c],0x076b076f  ;'ok'

    
;---------------------------------------------------------------    
;显示需要检测的总的单元个数
;---------------------------------------------------------------        
    mov byte [es:0x0b8140],'H'
    mov byte [es:0x0b8142],'E'
    mov byte [es:0x0b8144],'X'
    mov byte [es:0x0b8146],':'
    
    mov ebp,0x0b8140+10
    mov ecx,0
    call check
    
    mov byte [es:0x0b8140+30],'/'
    
    mov ebp,0x0b8140+34
    mov ecx,MEMORY_SIZE
    call check
	 
;---------------------------------------------------------------        
;内存检测
;以双字为单元，使用花码0x55aa55aa和0xaa55aa55进行内存检测
;---------------------------------------------------------------        
        
        xor ecx,ecx                 ;检测的单元个数
        mov ebx,MEMORY_START        ;检测的起始地址
	   
exam:   
        mov dword [es:ebx],0x55aa55aa
        cmp dword [es:ebx],0x55aa55aa
        jnz err
        
        mov dword [es:ebx],0xaa55aa55
        cmp dword [es:ebx],0xaa55aa55
        jnz err

        add ebx,4
        inc ecx
        mov byte  [es:0x0b80a0+28],'!'
        not byte  [es:0x0b80a0+29]
        
        
        mov ebp,0x0b8140+10
        call check
        
        cmp ebx,MEMORY_END
        jnz exam
        
        mov dword [es:0x0b80b0+20],0x076b076f       ;'ok'
        
;---------------------------------------------------------------        
err:
        hlt                         ;进入停机状态

        
;---------------------------------------------------------------
;子程序：check
;参数：    
;       ecx = 要显示的数值
;       ebp = 数值在显存的起始位置
;功能：    计算并显示检测的内存个数(以双字位单位)
;---------------------------------------------------------------
check:          push ebx
                push ecx
                push esi
                push eax
                push ebp
                
                mov eax,ecx
                xor ebx,ebx
                mov ecx,8
                mov esi,16
        digit:                 ; digit 和 show有对应关系 ，digit算出十六进制  ，show根据内存地址显示 ，（mem的值和number有映射关系）
                xor edx,edx
                div esi
                mov [mem+ebx],dl ; 得到余数，这个好像是在转成十六进制
                inc ebx
                loop digit
                
                
                xor edi,edi
                xor ebx,ebx
                mov esi,7
        show:   
                mov al,[mem+esi]
                mov bl,al          ; bl   下面ebx的低8位
                mov al,[number+ebx]
                mov [es:ebp+edi],al
                add edi,2
                dec esi
                jns show
        
                pop ebp
                pop eax
                pop esi
                pop ecx
                pop ebx
        
ret
;---------------------------------------------------------------
    mem     db  0,0,0,0,0,0,0,0     ;存放数位
    number  db '0123456789ABCDEF'
;---------------------------------------------------------------
    pdgt    dw  0
            dd  0x00007e00          ;GDT的物理地址
;---------------------------------------------------------------
    times 510-($-$$) db 0
                     db 0x55,0xaa