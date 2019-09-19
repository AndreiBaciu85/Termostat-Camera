#include <reg51.h>
sbit RS=P1^0;
sbit RW=P1^1;
sbit E=P1^2;
sbit Centrala=P1^3;
sbit Plus=P3^2;
sbit Minus=P3^3;
unsigned char temp[]={0, 0, 0, 0, 40, 0}; //valoare temperatura ascii
//temp[3]=old_adc_hex
//temp[4]=temp_set
//temp[5]=actual_temp
//----------------------------------------------------------------------------------------
//prototipuri
void init(void);
void text_disp(bit, unsigned char []);
void lcd_send(bit, unsigned char);
void delay_5ms(void);
void delay_30ms(void);
void convert(bit, unsigned char);
void temp_disp(bit);
unsigned char read_adc(void);
void compare(void);
void modify_trigger(void);
void Btn_plus(void) interrupt 0
{
	temp[4]++; 
	modify_trigger();
}
void Btn_minus(void) interrupt 2
{
	temp[4]--;
	modify_trigger();
}
//----------------------------------------------------------------------------------------						

void main()
{
	unsigned char text_temp[]= "Temp:"; //text
	unsigned char text_temp_set[]= "Temp:"; //text
	IE= 0x85;//INT0 si INT1 active
	TMOD=0x01;//Timer 0 mod 1
	IT0=1;//INT0 activ pe falling edge
	IT1=1;//INT1 activ pe falling edge
	P0=0xFF; //ADC
	P1=0x00; //biti control Start, RW, RS, etc.
	P2=0x00; //LCD
	P3=0xFF; //butoane
	init(); //initializare display
	text_disp(0, text_temp); //afisare text temp actuala
	text_disp(1, text_temp_set);//afisare text temp set
	temp_disp(1);//afisare temp set
	while(1)
	{
		temp_disp(0); //afisare temperatura actuala
		compare();//stare releu
		while(temp[3]==read_adc());//determinare valoare noua a temperaturii
	}
}

void lcd_send(bit reg, unsigned char c)
{
	P2=c;
	RS=reg; //RS=0 comanda / RS=1 date
	RW=0;
	E=1;
	delay_5ms();
	E=0; //tranzitie H->L
}
void init(void)
{
	//Comenzi initializare
	lcd_send(0, 0x3C); //Function Set
	delay_30ms();
	lcd_send(0, 0x06); //Entry Mode Set
	delay_30ms();
	lcd_send(0, 0x01); //Display Clear
	delay_30ms();
	lcd_send(0, 0x0C); //Display On
	delay_30ms();
}
void text_disp(bit line, unsigned char text[])
{
	int i;
	if(line==0)
	{
		for(i=0;i<5;i++) //afisare sir
		{
			lcd_send(1, text[i]);
			delay_30ms();
		}
		lcd_send(0, 0x8E); //pozitionare cursor
		delay_30ms();
	}
	else
	{
		lcd_send(0, 0xC0); //pozitionare cursor line 2
		delay_30ms();
		for(i=0;i<9;i++) //afisare sir
		{
			lcd_send(1, text[i]);
			delay_30ms();
		}
		lcd_send(0, 0xCE); //pozitionare cursor
		delay_30ms();
	}
	lcd_send(1, 0xDF); //afisare grad C
	delay_30ms();
	lcd_send(1, 0x43);
	delay_30ms();
	
}
void temp_disp(bit temperature_option)
{
	if(temperature_option==0)
	{
		 temp[3]=read_adc();//exemplar pentru verificare temperatura noua
		 convert(0, temp[3]);//conversie temperatura actuala
	}
	else
		convert(1, temp[4]);//conversie temperatura setata
	if(temp[0]!=-1) //verificare conversie reusita
	{
		if(temp[0]==0x30) //tratare caz temperatura [0, 10)
			temp[0]=' ';
		if(temperature_option==0)//afisare temperatura actuala
		{
			lcd_send(0, 0x8A);
			delay_30ms();
		}
		else
		{
			lcd_send(0, 0xCA);//afisare temperatura setata
			delay_30ms();
		}
		lcd_send(1, temp[0]);
		delay_30ms();
		lcd_send(1, temp[1]);
		delay_30ms();
		if(temp[2]==0) //verificare existenta 0.5 grade
		{
			lcd_send(1, ' ');
			delay_30ms();
			lcd_send(1, ' ');
			delay_30ms();
		}
		else
		{
			lcd_send(1, 0x2E); //afisare 0.5 grade
			delay_30ms();
			lcd_send(1, 0x35);
			delay_30ms();
		}
	} 
}
void convert(bit temperature_option, unsigned char hex_key)
{
	temp[0]=hex_key;
	if(temperature_option==0)//conversie hex->ascii
	{
		temp[0]=temp[0]/5;
		if((temp[0]>=0x00) && (temp[0]<=0x0D)) //0-13
		{
			if((hex_key%0x05==3) || (hex_key%0x05==4))//verificare rest
				temp[2]=1;
			else
				temp[2]=0;
		}
		if((temp[0]>=0x0E) && (temp[0]<=0x23))//13.5-34.5
		{
			if((hex_key%0x05==0) || (hex_key%0x05==1) || (hex_key%0x05==2))//verificare rest
			{
				if((hex_key%0x05==2) && ((temp[0]==0x0E) || (temp[0]==0x0F) || (temp[0]==0x10) || (temp[0]==0x11)))
					//caz special pentru 14,15,16,17 grade
					temp[2]=0;
				else
				{
					temp[0]=temp[0]-1;//factor corectie
					temp[2]=1;
				}
			}
			else
				temp[2]=0;
		}
		if((temp[0]>=0x24) && (temp[0]<=0x32))//35.5-50
		{
			if(hex_key%0x05!=4)
				temp[0]=temp[0]-1;//factor de corectie
			if((hex_key%0x05==2) || (hex_key%0x05==3))
				temp[2]=1;
			else
				temp[2]=0;
		}
	}
	else
	{
		temp[2]=temp[0]%2; //salvare rest temp set mod 2
		temp[0]=temp[0]>>1; //temp/2
	}
	temp[1]=temp[0]%0x0A+0x30; //cifra unitatilor ascii
	temp[0]=temp[0]/0x0A+0x30; //cifra zecilor ascii
}
void compare(void)
{
	unsigned char temp_set;
	unsigned char aux[4];
	aux[0]=temp[0];//salvare valori in cazul unui apel din intrerupere
	aux[1]=temp[1];
	aux[2]=temp[2];
	convert(1, temp[4]);//conversie temperatura setata
	temp_set=10*(temp[0]-0x30)+(temp[1]-0x30);//ascii->caracter
	aux[3]=temp[2];//0.5 grade
	convert(0, temp[3]);//conversie temperatura actuala
	temp[5]=10*(temp[0]-0x30)+(temp[1]-0x30);//ascii->caracter
	aux[4]=temp[2];//0.5 grade
	if(temp[5]>temp_set)//exemplu 50>20
		Centrala=0;
	if(temp[5]==temp_set)
	{
		if(aux[4]>=aux[3])//exemplu 20.5>20
			Centrala=0;
		else
			Centrala=1;//exemplu 20<20.5
	}
	else
		Centrala=1;//exemplu 15<20
	temp[0]=aux[0];//restaurare valori in cazul unui apel din intrerupere
	temp[1]=aux[1];
	temp[2]=aux[2];
}
void delay_5ms(void)
{
	TR0=0;
	TH0=0xEE;
	TL0=0x2A;
	TR0=1;
	while(TF0==0);
	TR0=0;
	TF0=0;
}
void delay_30ms(void)
{
	TR0=0;
	TH0=0x94;
	TL0=0xFB;
	TR0=1;
	while(TF0==0);
	TR0=0;
	TF0=0;
}
unsigned char read_adc(void)
{
	unsigned char hex_key;
	hex_key=P0; //salvare valoare
	return hex_key;
}

void modify_trigger(void)
{
	if(temp[4]==19) //temp set limit 10-28
		temp[4]=20;
	if(temp[4]==57)
		temp[4]=56;
	temp_disp(1); //afisare temp set
	compare(); //stare releu
}