#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <iostream>

#include <iostream>
#include <fstream>
#include <iterator>
#include <experimental/filesystem>
#include "binFile.h"
#include "linkList.h"

namespace fs = std::experimental::filesystem;

std::string getName(std::string name) {
	int ind = 0;
	for (int i = 0; i < name.length(); i++) {
		if (name.at(i) == '\\')
			ind = i;
	}
	return name.substr(ind + 1, name.length());
}

void getFile(bool isEncryptedFile, binFile & file, std::string path) {
	std::ifstream infile(path, std::ios::binary);
	infile.seekg(0, infile.end);
	int length = infile.tellg();
	infile.seekg(0, infile.beg);

	file.setName(getName(path));
	char* temp = new char[length];
	infile.read(temp, length);
	if (isEncryptedFile) {
		unsigned char t = temp[0];
		length = 0x00000000 | (unsigned int)t << 24;
		t = temp[1];
		length = length | (unsigned int)t << 16;
		t = temp[2];
		length = length | (unsigned int)t << 8;
		t = temp[3];
		length = length | (unsigned int)t;

		temp = &temp[4];
	}
	file.setFile(temp, length);
}

int getFileNum(std::string path) {
	int re = 0;
	for (auto& entry : fs::directory_iterator(path))
		re++;
	return re;
}

void getFiles(bool isEncryptedFile, binFile * &files, int fileNum, std::string path) {
	files = new binFile[fileNum];

	size_t ind = 0;
	for (const auto& entry : fs::directory_iterator(path)) {
		std::ifstream infile(entry.path(), std::ios::binary);
		infile.seekg(0, infile.end);
		int length = infile.tellg();
		infile.seekg(0, infile.beg);

		files[ind].setName(getName(entry.path().u8string()));
		char* temp = new char[length];
		infile.read(temp, length);
		if (isEncryptedFile) {
			unsigned char t = temp[0];
			length = 0x00000000 | (unsigned int)t << 24;
			t = temp[1];
			length = length | (unsigned int)t << 16;
			t = temp[2];
			length = length | (unsigned int)t << 8;
			t = temp[3];
			length = length | (unsigned int)t;

			temp = &temp[4];
		}
		files[ind].setFile(temp, length);
		ind++;
	}
}

void writeFiles(bool isEncrypt, binFile * files, int fileNum, std::string path) {
	for (int i = 0; i < fileNum; i++) {
		std::ofstream file;
		char* temp = files[i].getFile();
		file.open((path + files[i].getName()), std::ios::out | std::ios::binary);

		if (isEncrypt) {
			char* t = new char[4];
			int s = files[i].getSize();
			t[0] = s >> 24;
			t[1] = (s << 8) >> 24;
			t[2] = (s << 16) >> 24;
			t[3] = (s << 24) >> 24;

			for (int p = 0; p < 4; p++)
				file << t[p];
		}
		for (int p = 0; p < files[i].getSize(); p++)
			file << temp[p];

		file.close();
	}

}

void writeFile(bool isEncrypt, binFile files, std::string path) {
	std::ofstream file;
	file.open((path + files.getName()), std::ios::out | std::ios::binary);
	char* temp = files.getFile();
	if (isEncrypt) {
		char* t = new char[4];
		int s = files.getSize();
		t[0] = s >> 24;
		t[1] = (s << 8) >> 24;
		t[2] = (s << 16) >> 24;
		t[3] = (s << 24) >> 24;

		for (int p = 0; p < 4; p++)
			file << t[p];

		for (int p = 0; p < files.getSize(); p++)
			file << temp[p];

	}
	else {
		for (int p = 0; p < files.getSize(); p++)
			file << temp[p];

	}

	file.close();
}

__int32 genSequence(bool flipFirst, bool flipLast, __int16 firstID, __int16 lastID)
{
	int re = 0x00000000;
	re = re | (unsigned int)flipFirst << 31 | (unsigned int)firstID << 16 | (unsigned int)flipLast << 15 | (unsigned int)lastID;
	return re;
}

__int32** rnGen(std::string seed, int blockNum, int enLevel, int& sLength) {
	srand(1);
	int s = 0;
	for (int i = 0; i < seed.length(); i++)
		s += (int)seed.at(i) * rand();

	__int32** sequence = new __int32*[enLevel];
	if (blockNum % 2 == 1)
		sLength = (blockNum - 1) / 2;
	else
		sLength = blockNum / 2;

	srand(s * rand());
	for (int p = 0; p < enLevel; p++) {
		sequence[p] = new __int32[sLength];
		linkList* list = new linkList;
		for (int i = 0; i < blockNum; i++)
			list->add(i);

		for (int i = 0; i < sLength; i++) {
			sequence[p][i] = genSequence(rand() % 2 == 1, rand() % 2 == 1,
				(__int16)list->getContent(((float)rand() / RAND_MAX) * list->getSize() + 1),
				(__int16)list->getContent(((float)rand() / RAND_MAX) * list->getSize() + 1));
		}
	}
	return sequence;
}

__global__ void d_encrypt(char* array, __int32* sequence) {
	int blockID = blockIdx.x;
	__int32 s = sequence[blockID];

	__int16 ID1 = threadIdx.x + ((s << 1) >> 17)*blockDim.x;
	__int16 ID2 = threadIdx.x + ((s << 17) >> 17)*blockDim.x;
	bool flip1 = (s >> 31);
	bool flip2 = (s << 16) >> 31;

	if (flip1 == flip2)
	{
		array[ID1] = array[ID1] ^ array[ID2];
	}
	else if (flip1 && !flip2)
	{
		array[ID1] = (~array[ID1]) ^ array[ID2];
	}
	else if (!flip1 && flip2)
	{
		array[ID1] = array[ID1] ^ (~array[ID2]);
	}
}

__global__ void d_decrypt(char* array, __int32* sequence) {
	int blockID = blockIdx.x;
	__int32 s = sequence[blockID];

	__int16 ID1 = threadIdx.x + ((s << 1) >> 17) * blockDim.x;
	__int16 ID2 = threadIdx.x + ((s << 17) >> 17) * blockDim.x;
	bool flip1 = (s >> 31);
	bool flip2 = (s << 16) >> 31;

	if (flip1 == flip2)
	{
		array[ID1] = array[ID1] ^ array[ID2];
	}
	else if (flip1 && !flip2)
	{
		array[ID1] = array[ID1] ^ (~array[ID2]);
	}
	else if (!flip1 && flip2)
	{
		array[ID1] = (~array[ID1]) ^ array[ID2];
	}
}

void encrypt(binFile& file, int blockLength, __int32** sequence, int enLevel, int slength) {
	for (int i = 0; i < enLevel; i++) {
		__int32* d_s = NULL;
		char* d_bytes = NULL;

		dim3 block(blockLength);
		dim3 grid(slength);

		cudaMalloc((__int32**)& d_s, sizeof(__int32) * slength);
		cudaMalloc((char**)& d_bytes, sizeof(char) * file.getSize());
		cudaMemcpy(d_s, sequence[i], slength * sizeof(__int32), cudaMemcpyHostToDevice);
		cudaMemcpy(d_bytes, file.getFile(), file.getSize() * sizeof(char), cudaMemcpyHostToDevice);

		d_encrypt <<< grid, block >>> (d_bytes, d_s);

		char* h_temp;
		h_temp = (char*)malloc(sizeof(char) * file.getSize());
		cudaMemcpy(h_temp, d_bytes, file.getSize() * sizeof(char), cudaMemcpyDeviceToHost);
		file.setFile(h_temp, file.getSize());
		
		cudaFree(d_s);
		cudaFree(d_s);
		free(h_temp);
	}
}

void decrypt(binFile& file, int blockLength, __int32** sequence, int enLevel, int slength) {
	for (int i = enLevel - 1; i >= 0; i--) {
		__int32* d_s = NULL;
		char* d_bytes = NULL;

		dim3 block(blockLength);
		dim3 grid(slength);

		cudaMalloc((__int32 **)& d_s, sizeof(__int32) * slength);
		cudaMalloc((char**)& d_bytes, sizeof(char) * file.getSize());
		cudaMemcpy(d_s, sequence[i], slength * sizeof(__int32), cudaMemcpyHostToDevice);
		cudaMemcpy(d_bytes, file.getFile(), file.getSize() * sizeof(char), cudaMemcpyHostToDevice);

		d_decrypt <<< grid, block >>> (d_bytes, d_s);

		char* h_temp;
		h_temp = (char*)malloc(sizeof(char) * file.getSize());
		cudaMemcpy(h_temp, d_bytes, file.getSize() * sizeof(char), cudaMemcpyDeviceToHost);
		file.setFile(h_temp, file.getSize());

		cudaFree(d_s);
		cudaFree(d_s);
		free(h_temp);
	}
}

void deSequence(bool& flipFirst, bool& flipLast, __int16& firstID, __int16& lastID, __int32 sequence) {
	firstID = ((sequence << 1) >> 17);
	lastID = ((sequence << 17) >> 17);
	flipFirst = (sequence >> 31);
	flipLast = (sequence << 16) >> 31;
}
void encrypt_leg(char** array, int chunkDim, __int32 sequence) {
	__int16 chunk1ID, chunk2ID;
	bool flip1, flip2;
	deSequence(flip1, flip2, chunk1ID, chunk2ID, sequence);
	char* arr1 = array[chunk1ID];
	char* arr2 = array[chunk2ID];

	if (flip1 == flip2)
	{
		for (int i = 0; i < chunkDim; i++)
			arr1[i] = arr1[i] ^ arr2[i];
	}
	else if (flip1 && !flip2)
	{
		for (int i = 0; i < chunkDim; i++)
			arr1[i] = (~arr1[i]) ^ arr2[i];
	}
	else if (!flip1 && flip2)
	{
		for (int i = 0; i < chunkDim; i++)
			arr1[i] = arr1[i] ^ (~arr2[i]);
	}
}
void decrypt_leg(char** array, int chunkDim, __int32 sequence) {
	__int16 chunk1ID, chunk2ID;
	bool flip1, flip2;
	deSequence(flip1, flip2, chunk1ID, chunk2ID, sequence);
	char* arr1 = array[chunk1ID];
	char* arr2 = array[chunk2ID];

	if (flip1 == flip2)
	{
		for (int i = chunkDim - 1; i >= 0; i--)
			arr1[i] = arr1[i] ^ arr2[i];
	}
	else if (flip1 && !flip2)
	{
		for (int i = chunkDim - 1; i >= 0; i--)
			arr1[i] = arr1[i] ^ (~arr2[i]);
	}
	else if (!flip1 && flip2)
	{
		for (int i = chunkDim - 1; i >= 0; i--)
			arr1[i] = (~arr1[i]) ^ arr2[i];
	}
}

void test()
{

	std::string pass = "1";
	binFile file;
	getFile(false, file, "C:\\Users\\george\\Desktop\\1.txt");
	int slength;
	int blockDim = 2;
	int enlevel = 4;
	int blockNum = (file.getSize() + blockDim - 1) / blockDim;
	std::cout << blockNum << std::endl;
	__int32** s = rnGen(pass, blockNum, enlevel, slength);
	std::cout << slength << std::endl;

	char** c = new char* [blockNum];
	int ind = 0;
	char* f = file.getFile();
	for (int i = 0; i < blockNum; i++) {
		c[i] = new char[blockDim];
		for (int p = 0; p < blockDim; p++) {
			c[i][p] = f[ind];
			ind++;
		}
	}
	for (int i = 0; i < slength; i++)
		encrypt_leg(c, blockDim, s[0][i]);
	for (int i = slength - 1; i >= 0; i--)
		decrypt_leg(c, blockDim, s[0][i]);

	encrypt(file, blockDim, s, enlevel, slength);
	decrypt(file, blockDim, s, enlevel, slength);

	char* experimant = file.getFile();
	char* con = new char[file.getSize()];
	for (int i = 0; i < file.getSize(); i++)
		con[i] = c[i / blockDim][i % blockDim];

	for (int i = 0; i < slength; i++)
		std::cout << std::hex << s[0][i] << std::endl;

	for (int i = 0; i < file.getSize(); i++) {
		//	if (experimant[i] != con[i])
		std::cout << "error at index: " << i << " should be [" << con[i] << "] but was <" << experimant[i] << ">" << std::endl;
	}
}

int main(int argc, char** argv)
{
	int blockDim = 256;
	int blockNum;
	using namespace std;
	int isEncrypt = 1;
	string pass;
	string dir;
	string dirOut;
	int enlevel;
	cout << "Do you wants to encrypt(1) or decrypt(2)?" << endl;
	cin >> isEncrypt;
	cout << "Enter the directory or file pass you want to en/decrypt: ";
	cin >> dir;
	cout << "Enter the output directory: ";
	cin >> dirOut;
	cout << "Enter the pass word: ";
	cin >> pass;
	cout << "Enter the level of the encryption: ";
	cin >> enlevel;

	if (fs::is_directory(dir)) {
		binFile* files;
		int fileNum = getFileNum(dir);
		__int32*** s = new __int32** [fileNum];
		if (isEncrypt == 1) {
			getFiles(false, files, fileNum, dir);
			for (int i = 0; i < fileNum; i++) {
				blockNum = (files[i].getSize() + blockDim - 1) / blockDim;
				int slength;
				s[i] = rnGen(pass, blockNum, enlevel, slength);
				encrypt(files[i], blockNum, s[i], enlevel, slength);
			}
			writeFiles(true, files, fileNum, dirOut);
		}
		else if (isEncrypt == 2) {
			getFiles(true, files, fileNum, dir);
			for (int i = 0; i < fileNum; i++) {
				blockNum = (files[i].getSize() + blockDim - 1) / blockDim;
				int slength;
				s[i] = rnGen(pass, blockNum, enlevel, slength);
				decrypt(files[i], blockNum, s[i], enlevel, slength);
			}
			writeFiles(false, files, fileNum, dirOut);
		}
	}
	else {
		binFile file;
		int slength;
		__int32** s;
		if (isEncrypt == 1) {
			getFile(false, file, dir);
			blockNum = (file.getSize() + blockDim - 1) / blockDim;
			s = rnGen(pass, blockNum, enlevel, slength);
			encrypt(file, blockNum, s, enlevel, slength);
			writeFile(true, file, dirOut);
		}
		else if (isEncrypt == 2) {
			getFile(true, file, dir);
			blockNum = (file.getSize() + blockDim - 1) / blockDim;
			s = rnGen(pass, blockNum, enlevel, slength);
			decrypt(file, blockNum, s, enlevel, slength);
			writeFile(false, file, dirOut);
		}
	}

	return(0);
}
