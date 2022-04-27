import os

if __name__ == '__main__':
    print('start')
    suffix = '.asm';
    for file in os.listdir('./'):
        if file.rfind(suffix) >= 0:
            print('compile ' + file)
            file_name_prefix = file.replace(suffix,'')
            os.system('nasm  '+file +' -o '+file_name_prefix+'.bin  -l '+file_name_prefix+'.lst')
    print('end')
    input('')