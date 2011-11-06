#include <Ethernet.h>
#include <Udp.h>
#include <SPI.h>
#include <Time.h>
#include <TextFinder.h>

byte mac[] = { 
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 
  192,168,0,177 };
byte subnet[] = {
  255,255,255,0};
byte gateway[] = {
  192,168,0,1};
byte pachube[] = {
  173,203,98,29};
  
// Webserver
int websource = 0; // from where did the request come? 1=Stable, 2=Manual Run, 3=Test
  

// NTP Time stuff
byte timeServer[] = { 
  192,53,103,108 };

byte packetBuffer[48];

//ventilsteuerung
boolean delayrun = false;
boolean working = false;

int d0 = 0;
int d1 = 0;
int d2 = 0;
int d3 = 0;

// Misc
unsigned long runtime_temp = 0;
unsigned long runtime = 0;

// Program
int starthour = 22;
int startminute = 00;
int runtime_prog1 = 10;
int runtime_prog2 = 10;

//Manual Control via web
int man_enabled = 0;
int man_prog = 0;
long man_stoptime = 0;

// Webserver
Server server(80);

/*
Notes:
-MISC-
1 = Vorgarten
2 = Wiese
3 = Troepfchen
4 = Motor

-QUERY-
30 = 0
31 = 1
32 = 2
33 = 3
*/

// Thermo-Light-01
int analog0 = 0;
int analog1 = 0;
boolean update = false;
int relaystatus = 0;
byte ignore = 0;
int lightstarthour_01 = 06;
int lightstartminute_01 = 40;
int lightstophour_01 = 19;
int lightstopminute_01 = 30;


int routernum = 0;

void setup(){
  Serial.begin(9600);
  Serial1.begin(9600);
  Ethernet.begin(mac, ip);
  Udp.begin(8888);
  if (year() == 1970){
    getNTP();
    getNTP();
    //timedisplay();
    
  }
  stopall();
  Serial.println("Setup done!");
  delay(100);
}

void loop(){
  // Repeating Jobs
  if (second() == 30){
    delay(1000);
    repeater();
  }

  if (hour() == 15){
    if (minute() == 10){
      if (second() == 0){
        delay(1000);
        getNTP();
      }
    }
  }
  
  if (hour() == 1){
    if (minute() == 1){
      if (second() == 1){
        delayrun == false;
      }
    }
  }
  

  if (delayrun == false){
    if (hour() == starthour){
      if (minute() == startminute){
        if (second() == 0){
          delay(1000);
          xwater(41);
          xwater(41);
          delay(10);
          xwater(31);
          delay(10);
          xwater(11);
        }
      }
    
      if (minute() == (startminute + runtime_prog1)){
        if (second() == 0);
        delay(1000);
        xwater(21);
        delay(10);
        xwater(10);
      }
    
      if (minute() == (startminute + runtime_prog1 + runtime_prog2)){
        if (second() == 0)
        delay(1000);
        xwater(40);
        delay(10);
        xwater(30);
        delay(10);
        xwater(20);
      }
    }
  }
  webserver();
  
  if (man_enabled == true){
      man_progstart();
      man_enabled = false;
  }
  
  if (man_stoptime == now()){
    stopall();
  }
  
  // Thermo-Light-01
  lightcheck();
  if (update == true){
    if (analog0 != 0){
      Serial.print("Analog 0: ");
      Serial.println(analog0);
    }
  
    if (analog1 != 0){
      Serial.print("Analog 1: ");
      Serial.println(analog1);
      if (analog1 >= 900){
        if (relaystatus != 1){
          Serial.println("Schalte ein!");
          xlight(11);
          xlight(11);
        }
      }
      
      if (analog1 <= 900){
        if (relaystatus != 0){
          Serial.println("Schalte aus!");
          xlight(10);
          xlight(10);
        }
      }
    }
    update = false;
  }
  
}

void repeater(){
}

void man_progstart(){
  switch (man_prog){
    case 1:
    xwater(41);
    xwater(41);
    delay(10);
    xwater(31);
    delay(10);
    xwater(11);
    break;
    
    case 2:
    xwater(41);
    xwater(41);
    delay(10);
    xwater(31);
    delay(10);
    xwater(21);
    break;
    
    case 3:
    Serial.print("Not implemented yet!");
    break;
  }
}

void runtimer(){
  Serial.print("Runtime: ");
  if (runtime == 0){
    runtime = millis() / 1000;
    Serial.println(runtime);
    runtime_temp = now();
  }
  else{
    runtime = runtime + (now() - runtime_temp);
    Serial.println(runtime);
    runtime_temp = now();
  }
}


// Transfer commands to XBee
byte xtrans(byte value){
  Serial1.print(value, BYTE);
  //Serial.print(value, BYTE); //Debug-Option
  delay(10);
  return value;
}

// Build command and send it via xtrans
void xwater(int relay){
  xtrans(0x7E);
  xtrans(0x0);
  xtrans(0x10);
  long xcsum = 0;
  xcsum += xtrans(0x17);
  xcsum += xtrans(0x0);
  xcsum += xtrans(0x00);
  xcsum += xtrans(0x13);
  xcsum += xtrans(0xA2);
  xcsum += xtrans(0x00);
  xcsum += xtrans(0x40);
  xcsum += xtrans(0x6F);
  xcsum += xtrans(0x72);
  xcsum += xtrans(0xE8);
  xcsum += xtrans(0x77);
  xcsum += xtrans(0x55);
  xcsum += xtrans(0x17);
  xcsum += xtrans('D');
  switch (relay){
    case 10:
    xcsum += xtrans('0');
    xcsum += xtrans(0x4);
    break;
    
    case 11:
    xcsum += xtrans('0');
    xcsum += xtrans(0x5);
    break;
    
    case 20:
    xcsum += xtrans('1');
    xcsum += xtrans(0x4);
    break;
    
    case 21:
    xcsum += xtrans('1');
    xcsum += xtrans(0x5);
    break;
    
    case 30:
    xcsum += xtrans('2');
    xcsum += xtrans(0x4);
    break;
    
    case 31:
    xcsum += xtrans('2');
    xcsum += xtrans(0x5);
    break;
    
    case 40:
    xcsum += xtrans('3');
    xcsum += xtrans(0x4);
    break;
    
    case 41:
    xcsum += xtrans('3');
    xcsum += xtrans(0x5);
    break;
  }
  
  xtrans( 0xFF - (xcsum & 0xFF));  
}

// NTP Stuff
void getNTP()
{
  Udp.begin(8888);

  sendNTPpacket(timeServer); // send an NTP packet to a time server

    // wait to see if a reply is available
  delay(1000);  

  if ( Udp.available() ) {  
    Udp.readPacket(packetBuffer,48);
    unsigned long highWord = word(packetBuffer[40], packetBuffer[41]);
    unsigned long lowWord = word(packetBuffer[42], packetBuffer[43]);  
    unsigned long secsSince1900 = highWord << 16 | lowWord;  
    const unsigned long seventyYears = 2208988800UL;     
    unsigned long epoch = secsSince1900 - seventyYears;
    setTime(epoch);
    int dst = hour() + 2;
    setTime(dst,minute(),second(),day(),month(),year());
  }
}

unsigned long sendNTPpacket(byte *address)
{

  memset(packetBuffer, 0, 48); 
  packetBuffer[0] = 0b11100011;
  packetBuffer[1] = 0;
  packetBuffer[2] = 6;
  packetBuffer[3] = 0xEC;
  packetBuffer[12]  = 49; 
  packetBuffer[13]  = 0x4E;
  packetBuffer[14]  = 49;
  packetBuffer[15]  = 52;
  Udp.sendPacket( packetBuffer,48,  address, 123);
}

void stopall(){
 xwater(40);
 xwater(10);
 xwater(20);
 xwater(30);
 xlight(10); 
 
}

// Display the current time

void timedisplay(){
  Serial.print("Time: ");
  Serial.print(hour());
  Serial.print(":");
  Serial.print(minute());
  Serial.print(":");
  Serial.println(second());
}

void webserver(){
  server.begin();
  Client client = server.available();
  if (client) {
    TextFinder  finder(client );  
    while (client.connected()) {      
      if (client.available()) { 
        boolean dodelay = false;
        boolean dostop = false;
        boolean dogo = false;        
        if( finder.find("GET /") ) {              
          while(finder.findUntil("command", "\n\r")){  
            char type = client.read();
            int syntax_1 = finder.getValue();
            switch (type) {
              
              // STOP-Case
              case 'S':
              Serial.println("STOP!");
              stopall();
              break;
              
              // Delay-Case
              case 'D':
              Serial.println("Delay!");
              prog_delay();
              break;
              
              // GO-Case (manueller Start)
              case 'G':
              Serial.println("GO!");
              switch (syntax_1){
                case 10:
                xwater(41);
                delay(10);
                xwater(41);
                delay(10);
                xwater(31);
                delay(10);
                xwater(11);
                websource = 1;
                break;
                
                case 11:
                manual_run_prog1(10);
                websource = 2;
                break;
                
                case 12:
                manual_run_prog1(15);
                websource = 2;
                break;
                
                case 13:
                manual_run_prog1(20);
                websource = 2;
                break;
                
                case 14:
                manual_run_prog1(30);
                websource = 2;
                break;
                
                case 20:
                xwater(41);
                delay(10);
                xwater(41);
                delay(10);
                xwater(31);
                delay(10);
                xwater(21);
                websource = 1;
                break;
                
                case 21:
                manual_run_prog2(10);
                websource = true;
                break;
                
                case 22:
                manual_run_prog2(15);
                websource = 2;
                break;
                
                case 23:
                manual_run_prog2(20);
                websource = 2;
                break;
                
                case 24:
                manual_run_prog2(30);
                websource = 2;
                break;
                
                case 30:
                manual_run_prog12;
                websource = 2;
                break;
                
                // Relay-Control
                case 61:
                xrelay(11);
                websource = 3;
                break;
                
                case 62:
                xrelay(21);
                websource = 3;
                break;
                
                case 63:
                xrelay(31);
                websource = 3;
                break;
                
                case 64:
                xrelay(41);
                websource = 3;
                break;
                
                case 65:
                xrelay(51);
                websource = 3;
                break;
                
                case 66:
                xrelay(61);
                websource = 3;
                break;
                
                case 71:
                xrelay(10);
                websource = 3;
                break;
                
                case 72:
                xrelay(20);
                websource = 3;
                break;
                
                case 73:
                xrelay(30);
                websource = 3;
                break;
                
                case 74:
                xrelay(40);
                websource = 3;
                break;
                
                case 75:
                xrelay(50);
                websource = 3;
                break;
                
                case 76:
                xrelay(60);
                websource = 3;
                break;
                
                
                // Debug-Options
                case 81:
                xwater(41);
                break;
                
                case 82:
                xwater(11);
                websource = 2;
                break;
                
                case 83:
                xwater(21);
                websource = 2;
                break;
                
                case 84:
                xwater(31);
                websource = 2;
                break;
                
                case 85:
                xlight(11);
                websource = 2;
                break;
                
                case 91:
                xwater(40);
                websource = 2;
                break;
                
                case 92:
                xwater(10);
                websource = 2;
                break;
                
                case 93:
                xwater(20);
                websource = 2;
                break;
                
                case 94:
                xwater(30);
                websource = 2;
                break;
                
                case 95:
                xlight(10);
                websource = 2;
                break;
              }
              break;
              
              default:
              Serial.println("Keine Eingabe erkannt!");
            }
          }                         
        }
        client.println("HTTP/1.1 200 OK");
        client.println("Content-Type: text/html");
        client.println();
        client.println("<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">");
        client.println("<html <html xmlns=\"http://www.w3.org/1999/xhtml\">");
        client.println("<head>");
        client.println("<meta content=\"yes\" name=\"apple-mobile-web-app-capable\" />");
        client.println("<meta content=\"text/html; charset=utf-8\" http-equiv=\"Content-Type\" />");
        client.println("<meta content=\"minimum-scale=1.0, width=device-width, maximum-scale=0.6667, user-scalable=no\" name=\"viewport\" />");
        switch (websource){
          case 1:
          client.println("<meta http-equiv=\"refresh\" content=\"2; URL=http://control.techgarden.info/\">");
          break;
          
          case 2:
          client.println("<meta http-equiv=\"refresh\" content=\"2; URL=http://control.techgarden.info/index2.html\">");
          break;
          
          case 3:
          client.println("<meta http-equiv=\"refresh\" content=\"2; URL=http://test.techgarden.info/relays.html\">");
          break;
        }
        
        /*if (man_run == true){
          client.println("<meta http-equiv=\"refresh\" content=\"2; URL=http://control.techgarden.info/index2.html\">");
        }
        else{
          client.println("<meta http-equiv=\"refresh\" content=\"2; URL=http://control.techgarden.info/\">");
        }*/
        client.println("<link href=\"http://control.techgarden.info/css/style.css\" rel=\"stylesheet\" media=\"screen\" type=\"text/css\" />");
        client.println("<script src=\"http://control.techgarden.info/javascript/functions.js\" type=\"text/javascript\"></script>");
        client.println("<title>Befehl abgesetzt</title>");
        client.println("</head>");
        client.println("<body>");
        client.println("<div id=\"topbar\" class=\"transparent\">");
        client.println("<div id=\"leftnav\">");
        client.println("<a href=\"http://control.techgarden.info/\"><img alt=\"home\" src=\"http://control.techgarden.info/images/home.png\" /></a>");
        client.println("</div>");
        client.println("</div>");
        client.println("<div id=\"content\">");
        client.println("<span class=\"graytitle\">Eingabe erfolgreich</span>");
        client.println("<ul class=\"pageitem\">");
        client.print("<li class=\"textbox\"><span class=\"header\">Ihre Eingabe wurde bearbeitet</span><p>Durch diese Seite wird die Verarbeitung des Befehls quitiert.");
        client.println("Sie sollten autmoatisch weitergeleitet werden<br>Sollte dies nicht funktionieren - verwenden den Home Button</p></li></ul></ul>");
        client.println("<div id=\"footer\"><a href=\"http://iwebkit.net\">Powerd by iWebKit</a></div>");
        client.println("</body>");
        client.println("</html>");        
        break;        
      } 
    }
    delay(1);
    client.stop();
  }
}

void prog_delay(){
  delayrun == true;
}

void manual_run_prog1(int runlenght){
  man_enabled = true;
  man_prog = 1;
  man_stoptime = now() + (runlenght * 60);
}

void manual_run_prog2(int runlenght){
  man_enabled = true;
  man_prog = 2;
  man_stoptime = now() + (runlenght * 60);
}

void manual_run_prog12(int runlenght){
  man_enabled = true;
  man_prog = 3;
  man_stoptime = now() + (runlenght * 60);
}

void lightcheck(){
  if (Serial1.available() >= 20) {
    if (Serial1.read() == 0x7E) {
      update = true;
      ignore = Serial1.read(); //0x00 = MSB
      int LSB = Serial1.read(); // 0x14 - LSB
      //Serial.println(LSB);
      switch (LSB){
        case 22: 
        if (Serial1.read() == 0x92){
          delay(10);
            int s01 = Serial1.read(); // 0x00
            int s02 = Serial1.read(); // 0x13
            int s03 = Serial1.read(); // 0xa2
            int s04 = Serial1.read(); // 0x00
            int s05 = Serial1.read(); // 0x40
            int s06 = Serial1.read(); // 0x76 / 0x69
            int s07 = Serial1.read(); // 0x34 / 0x6c
            int s08 = Serial1.read(); // 0x83 / 0x9F
            int s10 = Serial1.read(); // 0xE1 / 0xDB
            int s11 = Serial1.read(); // 0x42 / 0x04
            int ro = Serial1.read(); // 0x01
            int sn = Serial1.read(); // 0x01
            int dm01 = Serial1.read(); // 0x00
            int dm02 = Serial1.read(); // 0x00
            int am01 = Serial1.read(); // 0x03
            ignore = Serial1.read();
            ignore = Serial1.read();
            int analog0_1 = Serial1.read(); //0x00 - 0x03
            int analog0_2 = Serial1.read(); // 0x00 - 0xFF
            int analog1_1 = Serial1.read(); // 0x00 - 0x03
            int analog1_2 = Serial1.read(); // 0x00 - 0xFF
            int cs = Serial1.read(); // Checksum
            analog0 = analog0_2 + (analog0_1 * 256);
            analog1 = analog1_2 + (analog1_1 * 256);
            }
            break;
      
      case 20:
      if (Serial1.read() == 0x92){
          delay(10);
            int s01 = Serial1.read(); // 0x00
            int s02 = Serial1.read(); // 0x13
            int s03 = Serial1.read(); // 0xa2
            int s04 = Serial1.read(); // 0x00
            int s05 = Serial1.read(); // 0x40
            int s06 = Serial1.read(); // 0x76 / 0x69
            int s07 = Serial1.read(); // 0x34 / 0x6c
            int s08 = Serial1.read(); // 0x83 / 0x9F
            int s10 = Serial1.read(); // 0xE1 / 0xDB
            int s11 = Serial1.read(); // 0x42 / 0x04
            int ro = Serial1.read(); // 0x01
            int sn = Serial1.read(); // 0x01
            int dm01 = Serial1.read(); // 0x00
            int dm02 = Serial1.read(); // 0x00
            int am01 = Serial1.read(); // 0x03
            int analog0_1 = Serial1.read(); //0x00 - 0x03
            int analog0_2 = Serial1.read(); // 0x00 - 0xFF
            int analog1_1 = Serial1.read(); // 0x00 - 0x03
            int analog1_2 = Serial1.read(); // 0x00 - 0xFF
            int cs = Serial1.read(); // Checksum
            analog0 = analog0_2 + (analog0_1 * 256);
            analog1 = analog1_2 + (analog1_1 * 256);
      }
      break;
      }
    }
  }
}

// XBee Light
void xlight(int state){
  xtrans(0x7E);
  xtrans(0x0);
  xtrans(0x10);
  long xcsum = 0;
  xcsum += xtrans(0x17);
  xcsum += xtrans(0x0);
  xcsum += xtrans(0x00);
  xcsum += xtrans(0x13);
  xcsum += xtrans(0xA2);
  xcsum += xtrans(0x00);
  xcsum += xtrans(0x40);
  xcsum += xtrans(0x69);
  xcsum += xtrans(0x6C);
  xcsum += xtrans(0x9F);
  xcsum += xtrans(0x11);
  xcsum += xtrans(0xC1);
  xcsum += xtrans(0x17);
  xcsum += xtrans('D');
  xcsum += xtrans('2');
  switch (state){
    case 11:
    xcsum += xtrans(0x5);
    relaystatus = 1;
    //Serial.println("Einschalten");
    break;
    
    case 10:
    xcsum += xtrans(0x4);
    relaystatus = 0;
    //Serial.println("Ausschalten");
    break;
  }
  xtrans( 0xFF - (xcsum & 0xFF));
}

void xrelay(int command){
  xtrans(0x7E);
  xtrans(0x0);
  xtrans(0x0F);
  long xcsum = 0;
  xcsum += xtrans(0x10);
  xcsum += xtrans(0x01);
  xcsum += xtrans(0x00);
  xcsum += xtrans(0x13);
  xcsum += xtrans(0xA2);
  xcsum += xtrans(0x00);
  xcsum += xtrans(0x40);
  xcsum += xtrans(0x69);
  xcsum += xtrans(0x6C);
  xcsum += xtrans(0xEB);
  xcsum += xtrans(0x86);
  xcsum += xtrans(0x4E);
  xcsum += xtrans(0x00);
  xcsum += xtrans(0x00);
  switch (command){
    case 11:
    xcsum += xtrans(0x0B);
    //Serial.println("Einschalten");
    break;
    
    case 10:
    xcsum += xtrans(0x0A);
    //Serial.println("Ausschalten");
    break;
    
    case 21:
    xcsum += xtrans(0x15);
    //Serial.println("Einschalten");
    break;
    
    case 20:
    xcsum += xtrans(0x14);
    //Serial.println("Ausschalten");
    break;
    
    case 31:
    xcsum += xtrans(0x1F);
    //Serial.println("Einschalten");
    break;
    
    case 30:
    xcsum += xtrans(0x1E);
    //Serial.println("Ausschalten");
    break;
    
    case 41:
    xcsum += xtrans(0x29);
    //Serial.println("Einschalten");
    break;
    
    case 40:
    xcsum += xtrans(0x28);
    //Serial.println("Ausschalten");
    break;
    
    case 51:
    xcsum += xtrans(0x33);
    //Serial.println("Einschalten");
    break;
    
    case 50:
    xcsum += xtrans(0x32);
    //Serial.println("Ausschalten");
    break;
    
    case 61:
    xcsum += xtrans(0x3D);
    //Serial.println("Einschalten");
    break;
    
    case 60:
    xcsum += xtrans(0x3C);
    //Serial.println("Ausschalten");
    break;
  }
  xtrans( 0xFF - (xcsum & 0xFF));
}

