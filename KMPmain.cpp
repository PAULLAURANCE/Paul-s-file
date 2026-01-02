#include <iostream>
#include <string>
using namespace std;
void getPai(string n, int* npai) {
	npai[0] = 0;
	int nlen = n.length();
	int i = 1, maxlen = 0;
	while (i < nlen) {
		if (n[i] == n[maxlen]) {
			maxlen++;
			npai[i] = maxlen;
			i++;
		}
		else {
			if (maxlen != 0) {
				maxlen = npai[maxlen - 1];
			}
			else {
				npai[i] = maxlen;
				i++;
			}
		}
	}
}
int KMPmain(string text, string pattern) {
	int tlen = text.length();
	int plen = pattern.length();
	int* pPai = new int[plen];
	getPai(pattern, pPai);
	int i = 0, j = 0;
	while (i < tlen) {
		if (text[i] == pattern[j]) {
			i++;
			j++;
		}
		if (j == plen) {
			delete[] pPai;
			return i - j;
		}
		else if (i < tlen && text[i] != pattern[j]) {
			if (j != 0) {
				j = pPai[j - 1];
			}
			else {
				i++;
			}
		}
	}
	return -1;
}
int main() {
	string text, pattern;
	cin >> text;
	cin >> pattern;
	int res = KMPmain(text, pattern);
	cout << res << endl;
	return 0;
}