#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>

// Program to illustrate the getopt() 
// function in C 
  
int main(int argc, char *argv[])  
{ 
    int opt; 
    int w;
    int c;
    int level = 0;
    // put ':' in the starting of the 
    // string so that program can  
    //distinguish between '?' and ':'  
    while((opt = getopt(argc, argv, ":w:c:")) != -1)  
    {  
        switch(opt)  
        {  
            case 'c':  
                sscanf(optarg, "%d", &c);
                break;  
            case 'w':  
                sscanf(optarg, "%d", &w);
                break;  
        }  
    }
      
	int ctemp;
	FILE * fd;
	fd = fopen("/sys/class/thermal/thermal_zone0/temp", "r");
    fscanf(fd, "%d", &ctemp);
	fclose(fd);
    ctemp = ctemp / 1000;
    if (ctemp >= c) {
        level = 2;
        printf("CRITICAL - CPU temperature is: %d\n", ctemp);
    } else if (ctemp >= w) {
        level = 1;
        printf("WARNING - CPU temperature is: %d\n", ctemp);
    } else {
        printf("OK - CPU temperature is: %d\n", ctemp);
    }
      
    return level; 
} 
