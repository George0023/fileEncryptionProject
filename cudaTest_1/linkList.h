#pragma once

struct node {
	int content;
	node* next = 0;
};

class linkList
{
private: 
	int size;
	node* start, * previous;
public:
	linkList();
	~linkList();
	bool add(int);
	int getContent(int);
	int getSize();
};

