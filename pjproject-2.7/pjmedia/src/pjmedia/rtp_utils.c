#include "pjmedia/rtp_utils.h"
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
const unsigned char *keyBuf = NULL;
unsigned int buffer_length=0;

int checkCPU()
{  
    short int test = 0x1234;

    if( *((char *)&test) == 0x12 )     //低地址存放高字节, 则是大端模式
        return 1;  
    else
        return 0;  
}

unsigned short BLEndianUshort(unsigned short value) {
    return ((value & 0x00FF) << 8 ) | ((value & 0xFF00) >> 8);
}

int pjmedia_key_clear()
{
    if(keyBuf)
        free(keyBuf);
    keyBuf = NULL;
    buffer_length=0;
    return 0;
}

int pjmedia_set_key(unsigned char* keybuf,unsigned int buflen)
{
	if (!keybuf)
	{
		printf("Invald argument!");
		return -1;
	}
	//printf("have set a key!\r\n");
	buffer_length = buflen;
    if (!keyBuf) 
        keyBuf=malloc(buflen);
    if(keyBuf)
        memcpy(keyBuf,keybuf,buflen);
	else
        return -1;
	return 0;
}

int encrypt_aes(unsigned char* input, unsigned int input_len,
    unsigned char* output,  unsigned int outbuf_len,
    unsigned char* key, unsigned char *iv, int padding) {
    AES_KEY  enc_key;
    AES_set_encrypt_key((unsigned char*)key,128, &enc_key);
    AES_cfb128_encrypt(input,output,input_len,&enc_key,key,&outbuf_len,AES_ENCRYPT);
    return 0;
}

int decrypt_aes(unsigned char* input, unsigned int input_len,
    unsigned char* output,  unsigned int outbuf_len,
    unsigned char* key, unsigned char *iv, int padding) {
    AES_KEY  enc_key;
    AES_set_decrypt_key((unsigned char*)key,128, &enc_key);
    AES_cfb128_encrypt(input,output,input_len,&enc_key,key,&outbuf_len,AES_DECRYPT);
    return 0;
}

int deal_send(void *input,int data_len,int head_len)
{
    if(!keyBuf) return -1;

	unsigned short seqnum = *((unsigned short*)((unsigned char*)input + 2));

    if (!checkCPU()) {
		seqnum = BLEndianUshort(seqnum);
	}

    int encryptOffset = seqnum/CHG_INTERVAL*KEY_LENGTH;
    if (encryptOffset >= (buffer_length-KEY_LENGTH)) {
        encryptOffset = (buffer_length-KEY_LENGTH);
    }

	unsigned char* iv = "0102030405060708";
    encrypt_aes((unsigned char*)input+head_len,data_len, (unsigned char*)input+head_len, data_len, keyBuf+encryptOffset, iv, 0);

    return 0;
}
int deal_receive(void *input,int data_len,int head_len)
{
    if(!keyBuf) return -1;
    //取出包序号：
    
    unsigned short on_seqnum =  *((unsigned short*)((pj_uint8_t*)input + 2));
    if (!checkCPU()) {
        on_seqnum = BLEndianUshort(on_seqnum);
    }

    int dencryptOffset = on_seqnum/CHG_INTERVAL*KEY_LENGTH;
    if (dencryptOffset >= (buffer_length-KEY_LENGTH)) {
        dencryptOffset = (buffer_length-KEY_LENGTH);
    }
    unsigned char* iv="0102030405060708";   
    decrypt_aes((unsigned char*)input+head_len, data_len, (unsigned char*)input+head_len, data_len, keyBuf+dencryptOffset, iv, 0);
    return 0;
}