#pragma once
#include <string>

class binFile {
	int size;
	char* bytes;
	std::string name;
public:
	void setFile(char*, int);
	void setName(std::string);
	std::string getName(void);
	int getSize(void);
	char* getFile(void);
};