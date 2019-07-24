#include "linkList.h"
#include <cstdlib>

linkList::linkList() {
	size = 0;
	start = previous = 0;
}

linkList::~linkList()
{
}

int linkList::getSize() {
	return size;
}

bool linkList::add(int value) {
	node* newNode = new node;
	newNode->content = value;
	newNode->next = 0;
	if (start == 0) {
		start = newNode;
		size++;
		return true;
	} else {
		node* temp = start;
		while (temp->next != 0) {
			temp = temp->next;
		}
		temp->next = newNode;
		size++;
		return true;
	}
	return false;
}

int linkList::getContent(int id) {
	if (id <= size) {
		node* temp = start;
		for (int i = 0; i < id; i++) {
			if (temp->next != 0) {
				previous = temp;
				temp = temp->next;
			}
		}
		int re = temp->content;
		previous->next = temp->next;
		free(temp);
		size--;
		return re;
	}
	return -1;
}
