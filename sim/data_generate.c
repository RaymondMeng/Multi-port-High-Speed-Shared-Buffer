#include <stdio.h>
#include <stdlib.h>
#include <time.h>

//unsigned long long ctrl_data;
unsigned char dest_port[100]; //100个package
unsigned char priority[100]; 
unsigned int length[100];

//package data随机生成 64-1024字节
unsigned char package_data; 
unsigned char dest_port_dat, priority_dat;
unsigned int length_dat;
unsigned long long ctrl_data = 0;

void data_init(){
    srand((unsigned int )time(NULL));
    for (int i = 0; i < 100; i++)
    {
        dest_port_dat = rand() % 16;
        priority_dat = rand() % 8;
        length_dat = rand() % 960 + 64;
        dest_port[i] = dest_port_dat;
        priority[i] = priority_dat;
        length[i] = length_dat;
    }
}

void port_data_generate(FILE *fp){
    data_init();
    for (int i = 0; i < 100; i++)
    {
        printf("length: %d priority: %d dest_port: %d\r\n", length[i], priority[i], dest_port[i]);
        ctrl_data = (length[i] << 7) | (priority[i] << 4) | dest_port[i];
        printf("%016x\n", ctrl_data);
        fprintf(fp, "%016x\n", ctrl_data);

        for (int j = 0; j < length[i]; j++)
        {
            package_data = rand() % 256;
            printf("%02x", package_data);
            fprintf(fp, "%02x", package_data);
            if ((j+1)%8 == 0)
            {
                printf("\n"); 
                fprintf(fp, "\n");
            }
            else if (j == length[i]-1)
            {
                printf("\n");
                fprintf(fp, "\n");
            }
        }
    }
}

int main(){

    FILE *fp1 = NULL;
    FILE *fp2 = NULL;
    FILE *fp3 = NULL;
    FILE *fp4 = NULL;
    FILE *fp5 = NULL;
    FILE *fp6 = NULL;
    FILE *fp7 = NULL;
    FILE *fp8 = NULL;
    FILE *fp9 = NULL;
    FILE *fp10 = NULL;
    FILE *fp11 = NULL;
    FILE *fp12 = NULL;
    FILE *fp13 = NULL;
    FILE *fp14 = NULL;
    FILE *fp15 = NULL;
    FILE *fp16 = NULL;

    fp1 = fopen("p1_data.txt", "w+");
    fp2 = fopen("p2_data.txt", "w+");
    fp3 = fopen("p3_data.txt", "w+");
    fp4 = fopen("p4_data.txt", "w+");
    fp5 = fopen("p5_data.txt", "w+");
    fp6 = fopen("p6_data.txt", "w+");
    fp7 = fopen("p7_data.txt", "w+");
    fp8 = fopen("p8_data.txt", "w+");
    fp9 = fopen("p9_data.txt", "w+");
    fp10 = fopen("p10_data.txt", "w+");
    fp11 = fopen("p11_data.txt", "w+");
    fp12 = fopen("p12_data.txt", "w+");
    fp13 = fopen("p13_data.txt", "w+");
    fp14 = fopen("p14_data.txt", "w+");
    fp15 = fopen("p15_data.txt", "w+");
    fp16 = fopen("p16_data.txt", "w+");

    port_data_generate(fp1);
    port_data_generate(fp2);
    port_data_generate(fp3);
    port_data_generate(fp4);
    port_data_generate(fp5);
    port_data_generate(fp6);
    port_data_generate(fp7);
    port_data_generate(fp8);
    port_data_generate(fp9);
    port_data_generate(fp10);
    port_data_generate(fp11);
    port_data_generate(fp12);
    port_data_generate(fp13);
    port_data_generate(fp14);
    port_data_generate(fp15);
    port_data_generate(fp16);

    fclose(fp1);
    fclose(fp2);
    fclose(fp3);
    fclose(fp4);
    fclose(fp5);
    fclose(fp6);
    fclose(fp7);
    fclose(fp8);
    fclose(fp9);
    fclose(fp10);
    fclose(fp11);
    fclose(fp12);
    fclose(fp13);
    fclose(fp14);
    fclose(fp15);
    fclose(fp16);
    return 0;
}