// Template.mq5
// Mateus Nascimento
// mateusnascimento.com

#property copyright "Mateus Nascimento"
#property link      "mateusnascimento.com"
#property version   "1.00"

// libraries
#include <Trade\Trade.mqh>
#include <MyIncludes\Logger.mqh>

// input parameters
input int       MaPeriod = 9;
input int       EaMagic = 10001;
input int       AssetsInStrategy = 5;
input double    StopLossSize = 0.5;


// indicators handles
int MaHandle;

// indicators value
double Ma[];

// aux variables
datetime LastTrade;
datetime LastTime;

// enums
enum ENUM_TREND {
    TREND_UP,
    TREND_DOWN,
    TREND_NONE
};

// objects
CTrade  trade;

// expert initialization function
int OnInit(){

    // set log configs
    CLogger::SetLevels(LOG_LEVEL_INFO, LOG_LEVEL_FATAL);
    CLogger::SetLoggingMethod(LOGGING_OUTPUT_METHOD_EXTERN_FILE);
    CLogger::SetNotificationMethod(NOTIFICATION_METHOD_MAILPUSH);
    CLogger::SetLogFileName(MQLInfoString(MQL_PROGRAM_NAME));
    CLogger::SetLogFileLimitType(LOG_FILE_LIMIT_TYPE_ONE_DAY);
    
    // define indicators handles
    MaHandle = iMA(_Symbol, _Period, MaPeriod, 0, MODE_SMA, PRICE_CLOSE);      
    
    // set arrays as time series
    ArraySetAsSeries(Ma, true);
    
    // config CTrade
    trade.SetExpertMagicNumber(EaMagic);
    trade.SetTypeFilling(ORDER_FILLING_RETURN);
    
    return(INIT_SUCCEEDED);
    
}

// expert deinitialization function
void OnDeinit(const int reason){
    IndicatorRelease(MaHandle);
}

// expert tick function
void OnTick(){

    if(IsNewBar()){    
        // update indicator every bar
        if(!UpdateIndicatorsOnBar()) return;
    }
        
    // update indicator every tick
    if(!UpdateIndicatorsOnTick()) return;
    
    // if last trade wasnt on current bar
    if(!(LastTrade == iTime(_Symbol, _Period, 0))){
       
        // if there's no position or order opened, check to open one
        if(PositionSelect(_Symbol) == false && IsAnyOrderOpened() == false){           
            
            //if(ConditionToOpenLong == true){
                LOG(LOG_LEVEL_INFO, "Signal to open long.");
                if(!OpenLong()) return;                        
            //}        
            // if trend is down
            //} else if(ConditionToOpenShort == true){
                LOG(LOG_LEVEL_INFO, "Signal to open short.");
                if(!OpenShort()) return;
            //}    
                    
        }
    }    
    
    // if there's a position, check to close it    
    if(PositionSelect(_Symbol) == true){
        // if it's a long position
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
            //if(ConditionToCloseLong == true){
                LOG(LOG_LEVEL_INFO, "Signal to close long.");
                if(!CloseLong()) return;
            //}
        // if it's a short position                
        } else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
            //if(ConditionToCloseShort == true){
                LOG(LOG_LEVEL_INFO, "Signal to close long.");
                if(!CloseShort()) return;
            //}
        }         
    }
}

// ***** CUSTOM FUNCTIONS ***** //

// close long position
bool CloseLong(){
    
    bool result = trade.PositionClose(_Symbol);
        
    if(result){
        LOG(LOG_LEVEL_INFO, "Long position closed successfully!");
        return result;
    } else {
        LOG(LOG_LEVEL_FATAL, "Error when trying to close long position! Code: " + (string)trade.ResultRetcode() + ", Description: " + trade.ResultRetcodeDescription());
        return result;
    }
}

// close short position
bool CloseShort(){
    
    bool result = trade.PositionClose(_Symbol);
        
    if(result){
        LOG(LOG_LEVEL_INFO, "Short position closed successfully!");
        return result;
    } else {
        LOG(LOG_LEVEL_FATAL, "Error when trying to close short position! Code: " + (string)trade.ResultRetcode() + ", Description: " + trade.ResultRetcodeDescription());
        return result;
    }
}

// get trend
ENUM_TREND GetTrend(double &Array[], int StartIndex, int Length){

    // ...
    return TREND_NONE;

}

// check order or position open
bool IsAnyOrderOpened(){  
    for(int i = OrdersTotal()-1; i >= 0; i--){
        if(OrderSelect(OrderGetTicket(i))){
            if(OrderGetString(ORDER_SYMBOL) == _Symbol){
                return true;
            }
        }       
    }    
    return false;
}

// check if a Array is decreasing, given a certain length
bool IsDecreasing(double &Array[], int StartIndex, int Length){
    bool result = true;
    for(int i = StartIndex; i < Length + StartIndex; i++){
        if(Array[i] >= Array[i + 1]){
            result = false;
        }        
    }
    return result;
}

// check if a Array is increasing, given a certain length
bool IsIncreasing(double &Array[], int StartIndex, int Length){
    bool result = true;
    for(int i = StartIndex; i < Length + StartIndex; i++){
        if(Array[i] <= Array[i + 1]){
            result = false;
        }        
    }
    return result;
}

// Check if is a new bar
bool IsNewBar(){    
    datetime CurrentTime = iTime(_Symbol, _Period, 0);
    
    if(LastTime == CurrentTime){
        return false;
    } else {
        LastTime = CurrentTime;
        return true;
    }        
}

// return amount of money in symbol (pending orders + position)
double MoneyInSymbol(){
    double MoneyPosition = 0;
    double MoneyOrders = 0;
    if(PositionSelect(_Symbol) == true) MoneyPosition = (PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME));    
    for(int i = OrdersTotal()-1; i >= 0; i--){
        if(OrderSelect(OrderGetTicket(i))){
            if(OrderGetString(ORDER_SYMBOL) == _Symbol){
                MoneyOrders = MoneyOrders + (OrderGetDouble(ORDER_PRICE_OPEN) * OrderGetDouble(ORDER_VOLUME_CURRENT));
            }
        }       
    }
    LOG(LOG_LEVEL_INFO, "MoneyPosition: " + (string)MoneyPosition + ", MoneyOrders: " + (string)MoneyOrders);
    double Money = NormalizeDouble(MoneyPosition + MoneyOrders, 2);
    return Money;    
}

// open long position
bool OpenLong(){

    double Volume = Volume();
    double Price = 0;
    double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double StopLoss = 0;       
    double TakeProfit = 0;
    LOG(LOG_LEVEL_INFO, "StopLoss: " + (string)StopLoss + ", TakeProfit: " + (string)TakeProfit);
    
    // double check looking for opened positions or orders
    double MoneyInSymbol = MoneyInSymbol();
    if(MoneyInSymbol > 0){
        LOG(LOG_LEVEL_ERROR, "Error when trying to open long position. Symbol has already $" + (string)MoneyInSymbol + " on positions or pendings orders.");
        return true;
    }
    
    bool result = trade.Buy(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL); 
    
    if(result){
        LOG(LOG_LEVEL_INFO, "Long position opened successfully.");
        return true;
    } else {
        if(trade.ResultRetcode() == TRADE_RETCODE_NO_MONEY){
            Volume = Volume - 100;
            LOG(LOG_LEVEL_WARNING, "Order rejected due to 'NO MONEY', trying new volume(" + (string)Volume + ")...");
            result = trade.Buy(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL);
            if(result){
                LastTrade = iTime(_Symbol, _Period, 0);
                LOG(LOG_LEVEL_INFO, "Long position opened successfully."); 
                return true;
            }            
        }
        LOG(LOG_LEVEL_ERROR, "Error when trying to open long position. Code: " + (string)trade.ResultRetcode() + ", Description: " + trade.ResultRetcodeDescription());        
        return false;
    }
}

// open short position
bool OpenShort(){

    double Volume = Volume();
    double Price = 0;
    double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double StopLoss = 0;       
    double TakeProfit = 0;
    LOG(LOG_LEVEL_INFO, "StopLoss: " + (string)StopLoss + ", TakeProfit: " + (string)TakeProfit);
    
    // double check looking for opened positions or orders
    double MoneyInSymbol = MoneyInSymbol();
    if(MoneyInSymbol > 0){
        LOG(LOG_LEVEL_ERROR, "Error when trying to open short position. Symbol has already $" + (string)MoneyInSymbol + " on positions or pendings orders.");
        return true;
    }
    
    bool result = trade.Sell(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL); 
    
    if(result){
        LOG(LOG_LEVEL_INFO, "Short position opened successfully.");
        return true;
    } else {
        if(trade.ResultRetcode() == TRADE_RETCODE_NO_MONEY){
            Volume = Volume - 100;
            LOG(LOG_LEVEL_WARNING, "Order rejected due to 'NO MONEY', trying new volume(" + (string)Volume + ")...");
            result = trade.Sell(Volume, _Symbol, Price, StopLoss, TakeProfit, NULL);
            if(result){
                LastTrade = iTime(_Symbol, _Period, 0);
                LOG(LOG_LEVEL_INFO, "Short position opened successfully."); 
                return true;
            }            
        }
        LOG(LOG_LEVEL_ERROR, "Error when trying to open short position. Code: " + (string)trade.ResultRetcode() + ", Description: " + trade.ResultRetcodeDescription());        
        return false;
    }
}

// update indicators on bar
bool UpdateIndicatorsOnBar(){
    
    // updating and checking for erros
    if(CopyBuffer(MaHandle, 0, 0, 1, Ma)   < 0 ){        
        LOG(LOG_LEVEL_ERROR, "Error updating indicators 'on bar'. Code: " + (string)GetLastError());
        return false;
    } else {
        return true;
    }
}

// update indicators on tick
bool UpdateIndicatorsOnTick(){
    // updating and checking for erros
    if(CopyBuffer(MaHandle, 0, 0, 1, Ma)   < 0 ){        
        LOG(LOG_LEVEL_ERROR, "Error updating indicators 'on bar'. Code: " + (string)GetLastError());
        return false;
    } else {
        return true;
    }
}

double Volume(){
    double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double LastPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
    //double Volume = MathFloor(AccountBalance / LastPrice / AssetsInStrategy / 100) * 100;
    double Volume = 0; // implementar lógica de volume
    LOG(LOG_LEVEL_INFO, "Volume:  " + (string)Volume + ", AccountBalance: " + (string)AccountBalance + ", LastPrice: " + (string)LastPrice);
    return Volume;
}

