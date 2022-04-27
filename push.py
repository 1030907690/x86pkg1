import os

if __name__ == '__main__':
    print('start')
    desc = input('please input commit desc ');

    os.system('git add .')
    os.system('git commit -m \''+desc+'\'')
    os.system('git push')
    print('end')
    input('')