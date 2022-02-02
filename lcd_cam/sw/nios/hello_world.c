/*
 * "Hello World" example.
 *
 * This example prints 'Hello from Nios II' to the STDOUT stream. It runs on
 * the Nios II 'standard', 'full_featured', 'fast', and 'low_cost' example
 * designs. It runs with or without the MicroC/OS-II RTOS and requires a STDOUT
 * device in your system's hardware.
 * The memory footprint of this hosted application is ~69 kbytes by default
 * using the standard reference design.
 *
 * For a reduced footprint version of this template, and an explanation of how
 * to reduce the memory footprint for a given application, see the
 * "small_hello_world" template.
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <io.h>
#include <time.h>
#include <stdint.h>
#include <unistd.h>
#include <stdbool.h>
#include <inttypes.h>
#include <sys/alt_cache.h>
#include "system.h"
#include "i2c/i2c.h"

#define BURST_LENGTH 8
#define FRAME_PIXEL 0x00009600 //38400
#define FRAME_DEFAULT_ADDRESS HPS_0_BRIDGES_BASE
#define FRAME_SPAN FRAME_PIXEL*4

#define I2C_FREQ              (50000000) /* Clock frequency driving the i2c core: 50MHz */

#define TRDB_D5M_I2C_ADDRESS  (0xba)
#define TRDB_D5M_I2C_ROWSIZE_OFFSET  (3) //camera i2c internal registers offsets
#define TRDB_D5M_I2C_COLSIZE_OFFSET  (4)
#define TRDB_D5M_I2C_PIXCLKCTRL_OFFSET  (10)
#define TRDB_D5M_I2C_READMODE1_OFFSET  (30)
#define TRDB_D5M_I2C_ROWADDRESSMODE_OFFSET  (34)
#define TRDB_D5M_I2C_COLADDRESSMODE_OFFSET  (35)
#define TRDB_D5M_I2C_RESTART_OFFSET  (11)

#define CAMCONTROLLER_AMADDRESS_OFFSET (0) //camera controller internal registers offsets
#define CAMCONTROLLER_AMLENGTH_OFFSET (4)
#define CAMCONTROLLER_START_OFFSET (8)
#define CAMCONTROLLER_CMD_OFFSET (12)      //power command
#define CAMCONTROLLER_AMSTATUS_OFFSET (16)
#define CAMCONTROLLER_PWSTATUS_OFFSET (20)
#define CAMCONTROLLER_CAMINTSTATUS_OFFSET (24)
#define CAMCONTROLLER_BURSTSTATUS_OFFSET (28)

#define ONE_MB (1024 * 1024)


bool trdb_d5m_write(i2c_dev *i2c, uint8_t register_offset, uint16_t data) {
    uint8_t byte_data[2] = {(data >> 8) & 0xff, data & 0xff};

    int success = i2c_write_array(i2c, TRDB_D5M_I2C_ADDRESS, register_offset, byte_data, sizeof(byte_data));

    if (success != I2C_SUCCESS) {
        return false;
    } else {
        return true;
    }
}

bool trdb_d5m_read(i2c_dev *i2c,  uint8_t register_offset, uint16_t *data) {
    uint8_t byte_data[2] = {0, 0};

    int success = i2c_read_array(i2c, TRDB_D5M_I2C_ADDRESS, register_offset, byte_data, sizeof(byte_data));

    if (success != I2C_SUCCESS) {
        return false;
    } else {
        *data = ((uint16_t) byte_data[0] << 8) + byte_data[1];
        return true;
    }
}

void set_lcd_reset(){
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0,0x0000003A);
}

void clear_lcd_reset(){

	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0,0x0000001A);
}

void send_command(uint32_t command){
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0,command);
}

void set_command_data(uint32_t command){

		IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0,command);
}

void set_startaddress(uint32_t startaddress){

		IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 4, startaddress);
}

void set_framelength(uint32_t framelength){

		IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 8,framelength);
}

void init_LCD() {
	set_lcd_reset();// RESET
	usleep(1000);
	clear_lcd_reset();// STOP RESET
	usleep(10000);
	set_lcd_reset();// RESET
	usleep(120000);


	send_command(0x00110002); // EXITSLEEP
	send_command(0x00CF8002);// POWER CONTROL B
		send_command(0x00008003);
		send_command(0x00818003);
		send_command(0x00C00003);
	send_command(0x00ED8002);
		send_command(0x00648003);
		send_command(0x00038003);
		send_command(0x00128003);
		send_command(0x00810003);
	send_command(0x00E88002);
		send_command(0x00858003);
		send_command(0x00018003);
		send_command(0x07980003);
	send_command(0x00CB8002);
		send_command(0x00398003);
		send_command(0x002C8003);
		send_command(0x00008003);
		send_command(0x00348003);
		send_command(0x00020003);
	send_command(0x00F78002);
		send_command(0x00200003);
	send_command(0x00EA8002);
		send_command(0x00008003);
		send_command(0x00000003);
	send_command(0x00B18002);
		send_command(0x00008003);
		send_command(0x001B0003);
	send_command(0x00B68002);
		send_command(0x000A8003);
		send_command(0x00A20003);
	send_command(0x00C08002);
		send_command(0x00050003);
	send_command(0x00C18002);
		send_command(0x00110003);
	send_command(0x00C58002);
		send_command(0x00458003);
		send_command(0x00450003);
	send_command(0x00C78002);
		send_command(0x00A20003);
	send_command(0x00368002);
		//send_command(0x00080003);
		send_command(0x00280003);
	send_command(0x00F28002);
		send_command(0x00000003);
	send_command(0x00268002);
		send_command(0x00010003);
	send_command(0x00E08002);
		send_command(0x000F8003);
		send_command(0x00268003);
		send_command(0x00248003);
		send_command(0x000B8003);
		send_command(0x000E8003);
		send_command(0x00088003);
		send_command(0x004B8003);
		send_command(0x00A88003);
		send_command(0x003B8003);
		send_command(0x000A8003);
		send_command(0x00148003);
		send_command(0x00068003);
		send_command(0x00108003);
		send_command(0x00098003);
		send_command(0x00000003);
	send_command(0x00E18002);
		send_command(0x00008003);
		send_command(0x001C8003);
		send_command(0x00208003);
		send_command(0x00048003);
		send_command(0x00108003);
		send_command(0x00088003);
		send_command(0x00348003);
		send_command(0x00478003);
		send_command(0x00448003);
		send_command(0x00058003);
		send_command(0x000B8003);
		send_command(0x00098003);
		send_command(0x002F8003);
		send_command(0x00368003);
		send_command(0x000F0003);
	send_command(0x002A8002);
		send_command(0x00008003);
		send_command(0x00008003);
		send_command(0x00018003);
		send_command(0x003F0003);
	send_command(0x002B8002);
		send_command(0x00008003);
		send_command(0x00008003);
		send_command(0x00008003);
		send_command(0x00EF0003);
	send_command(0x003A8002);
		send_command(0x00550003);
	send_command(0x00F68002);
		send_command(0x00018003);
		send_command(0x00308003);
		send_command(0x00000003);
	send_command(0x00290002);
	send_command(0x002C8002);
}


int checkmemory()
{
    uint32_t megabyte_count = 0;

    for (uint32_t i = 0; i < HPS_0_BRIDGES_SPAN; i += sizeof(uint32_t)) {

        // Print progress through 256 MB memory available through address span expander
        if ((i % ONE_MB) == 0) {
            //printf("megabyte_count = %" PRIu32 "\n", megabyte_count);
            megabyte_count++;
        }

        uint32_t addr = HPS_0_BRIDGES_BASE + i;

        // Write through address span expander
        uint32_t writedata = i;
        IOWR_32DIRECT(addr, 0, writedata);

        // Read through address span expander
        uint32_t readdata = IORD_32DIRECT(addr, 0);

        // Check if read data is equal to written data
        if(writedata != readdata){
        	return EXIT_FAILURE;
        }
    }

    return EXIT_SUCCESS;
}

void powerCamera(uint32_t cmd) {

	IOWR_32DIRECT(CAMCONTROLLER_0_BASE, CAMCONTROLLER_CMD_OFFSET, cmd);
	uint32_t status_power;
	if(cmd)
		status_power = 1; //powered up
	else
		status_power = 0; //powered down

	while((IORD_32DIRECT(CAMCONTROLLER_0_BASE,CAMCONTROLLER_PWSTATUS_OFFSET)) != status_power) {
	}

}

int configureCamera_i2c(i2c_dev i2c) {

	i2c_init(&i2c, I2C_FREQ);

	bool success = true;

	uint16_t rowsize = 1919; //binning 4x
	success &= trdb_d5m_write(&i2c, TRDB_D5M_I2C_ROWSIZE_OFFSET, rowsize);

	uint16_t colsize = 2559; //binning 4x
	success &= trdb_d5m_write(&i2c, TRDB_D5M_I2C_COLSIZE_OFFSET, colsize);

	//snapshot mode
	uint16_t readmode1 = 0x0100;
	success &= trdb_d5m_write(&i2c, TRDB_D5M_I2C_READMODE1_OFFSET, readmode1);

	//row binning and skipping 4x
	uint16_t rowAddressMode = 0x0033;
	success &= trdb_d5m_write(&i2c, TRDB_D5M_I2C_ROWADDRESSMODE_OFFSET, rowAddressMode);

	//col binning and skipping 4x
	uint16_t colAddressMode = 0x0033;
	success &= trdb_d5m_write(&i2c, TRDB_D5M_I2C_COLADDRESSMODE_OFFSET, colAddressMode);
	
	//restart
	success &= trdb_d5m_write(&i2c, TRDB_D5M_I2C_RESTART_OFFSET, 3);

	uint16_t pixClkCtrl = 0x8000;
	success &= trdb_d5m_write(&i2c, TRDB_D5M_I2C_PIXCLKCTRL_OFFSET, pixClkCtrl);

	success &= trdb_d5m_write(&i2c, TRDB_D5M_I2C_RESTART_OFFSET, 1);

	if (success) {
		return EXIT_SUCCESS;
	} else {
		return EXIT_FAILURE;
	}
}

void startcamera(uint32_t address_memory)
{
	uint32_t length = 2400;
	uint32_t start = 1;

	IOWR_32DIRECT(CAMCONTROLLER_0_BASE, CAMCONTROLLER_AMADDRESS_OFFSET, address_memory);
	IOWR_32DIRECT(CAMCONTROLLER_0_BASE, CAMCONTROLLER_AMLENGTH_OFFSET, length);
	IOWR_32DIRECT(CAMCONTROLLER_0_BASE, CAMCONTROLLER_START_OFFSET, start);
	
}

int check_cam_config_i2c(i2c_dev i2c) {

	bool success = true;

	uint16_t rowsize = 0;
	success &= trdb_d5m_read(&i2c, TRDB_D5M_I2C_ROWSIZE_OFFSET, &rowsize);

	uint16_t colsize = 0;
	success &= trdb_d5m_read(&i2c, TRDB_D5M_I2C_COLSIZE_OFFSET, &colsize);

	uint16_t pixClkCtrl = 0;
	success &= trdb_d5m_read(&i2c, TRDB_D5M_I2C_PIXCLKCTRL_OFFSET, &pixClkCtrl);

	uint16_t readmode1 = 0;
	success &= trdb_d5m_read(&i2c, TRDB_D5M_I2C_READMODE1_OFFSET, &readmode1);

	uint16_t rowAddressMode = 0;
	success &= trdb_d5m_read(&i2c, TRDB_D5M_I2C_ROWADDRESSMODE_OFFSET, &rowAddressMode);

	uint16_t colAddressMode = 0;
	success &= trdb_d5m_read(&i2c, TRDB_D5M_I2C_COLADDRESSMODE_OFFSET, &colAddressMode);

	if (rowsize==1919 && colsize==2559 && pixClkCtrl==0x8000 && readmode1==0x0100
		&& rowAddressMode==0x0033 && colAddressMode==0x0033  && success) {
		return EXIT_SUCCESS;
	} else {
		return EXIT_FAILURE;
	}

}
int triggerCamera_i2c(i2c_dev i2c) {

	bool success = true;

	uint16_t trigger = 0x0004;
	success &= trdb_d5m_write(&i2c, TRDB_D5M_I2C_RESTART_OFFSET, trigger); //set trigger bit

	// trigger not auto reset
	success &= trdb_d5m_write(&i2c, TRDB_D5M_I2C_RESTART_OFFSET, 0);

	if (success) {
		return EXIT_SUCCESS;
	} else {
		return EXIT_FAILURE;
	}
}
int main()
{
	uint32_t cmd = 1;
	powerCamera(cmd); //power up 

	i2c_dev i2c = i2c_inst((void *) I2C_0_BASE);
	
	if (configureCamera_i2c(i2c)!=EXIT_SUCCESS)
		return EXIT_FAILURE;

	if (check_cam_config_i2c(i2c)!=EXIT_SUCCESS)
	    return EXIT_FAILURE;

	init_LCD();

	int countframe=1;
	uint32_t offset=153600;
	uint32_t address_memory_lcd;
	uint32_t address_memory_camera=HPS_0_BRIDGES_BASE;
	bool wait_cam, wait_lcd = true;

	startcamera(address_memory_camera);
	
	// write first image
	if (triggerCamera_i2c(i2c)!=EXIT_SUCCESS)
		return EXIT_FAILURE;
		
	while(wait_cam){
		uint32_t DMAstatus = IORD_32DIRECT(CAMCONTROLLER_0_BASE,CAMCONTROLLER_AMSTATUS_OFFSET);
		if((DMAstatus==2))
			wait_cam = 0;
	}

	while(countframe!=1000){
	
	    address_memory_camera=HPS_0_BRIDGES_BASE + offset;
		address_memory_lcd=HPS_0_BRIDGES_BASE;
		startcamera(address_memory_camera);
		
		if (triggerCamera_i2c(i2c)!=EXIT_SUCCESS)
			return EXIT_FAILURE;
		
		set_framelength(0x00009600);
		set_startaddress(address_memory_lcd);
		send_command(0x002C8002);
		set_command_data(0x0000C840);
		wait_cam = true;

		while(wait_cam){
			uint32_t DMAstatus = IORD_32DIRECT(CAMCONTROLLER_0_BASE,CAMCONTROLLER_AMSTATUS_OFFSET);
			if((DMAstatus==2))
				wait_cam = 0;
		}

		wait_lcd = true;
		while(wait_lcd){
			if(((IORD_32DIRECT(LCD_CONTROLLER_0_BASE,0)&0x00000040)>>8) == 0)
				wait_lcd = false;

		}
		countframe=countframe+1;

		address_memory_camera=HPS_0_BRIDGES_BASE;
		address_memory_lcd=HPS_0_BRIDGES_BASE + offset;
		startcamera(address_memory_camera);
		if (triggerCamera_i2c(i2c)!=EXIT_SUCCESS)
			return EXIT_FAILURE;
			
		set_framelength(0x00009600);
		set_startaddress(address_memory_lcd);
		send_command(0x002C8002);
		set_command_data(0x0000C840);
		wait_cam = true;

		while(wait_cam){
			uint32_t DMAstatus = IORD_32DIRECT(CAMCONTROLLER_0_BASE,CAMCONTROLLER_AMSTATUS_OFFSET);
			if((DMAstatus==2))
				wait_cam = 0;
		}

		wait_lcd = true;
		while(wait_lcd){
			if(((IORD_32DIRECT(LCD_CONTROLLER_0_BASE,0)&0x00000040)>>6) == 0)
				wait_lcd = false;
		}
		
		countframe=countframe+1;
	}
	
	printf("All Frames displayed\n");
}
