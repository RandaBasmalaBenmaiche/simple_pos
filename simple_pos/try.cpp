#include <iostream>

using namespace std;






int main(){

    int c = 5;
    int d = 5;





    pl(d);
    cout << d << endl;
    void pl(int);



    return 0;
}
    void pl(int i){ 
    i = i + 1;
    cout << "non ref" <<i << endl;
    return ; 
}