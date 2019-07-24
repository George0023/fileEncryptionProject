#include "binFile.h"
#include <iostream>

void binFile::setName(std::string nameOfTheFile) {
	name = nameOfTheFile;
}

std::string binFile::getName() {
	return name;
}

void binFile::setFile(char* files, int size) {
	bytes = new char [size];
	this->size = size;
	for (int i = 0; i < size; i++) {
		bytes[i] = files[i];
	}
}

int binFile::getSize() {
	return size;
}


char* binFile::getFile() {
	return bytes;
}
