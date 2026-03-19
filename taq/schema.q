/ Table master: EQY_US_ALL_REF_MASTER_*.csv
MASTERSCHEMA: ([
  Symbol:"*";
  Security_Description:"*";
  CUSIP:"S";
  Security_Type:"S";
  SIP_Symbol:"S";
  Old_Symbol:"S";
  Test_Symbol_Flag:"B";
  Listed_Exchange:"C";
  Tape:"C";
  Unit_Of_Trade:"H";
  Round_Lot:"H";
  NYSE_Industry_Code:"S";
  Shares_Outstanding:"F";
  Halt_Delay_Reason:"C";
  Specialist_Clearing_Agent:"S";
  Specialist_Clearing_Number:"S";
  Specialist_Post_Number:"H";
  Specialist_Panel:"C";
  TradedOnNYSEMKT:"B";
  TradedOnNASDAQBX:"B";
  TradedOnNSX:"B";
  TradedOnFINRA:"B";
  TradedOnISE:"B";
  TradedOnEdgeA:"B";
  TradedOnEdgeX:"B";
  TradedOnNYSETexas:"B";
  TradedOnNYSE:"B";
  TradedOnArca:"B";
  TradedOnNasdaq:"B";
  TradedOnCBOE:"B";
  TradedOnPSX:"B";
  TradedOnBATSY:"B";
  TradedOnBATS:"B";
  TradedOnIEX:"B";
  Tick_Pilot_Indicator:"C";
  Effective_Date:"D";
  TradedOnLTSE:"B";
  TradedOnMEMX:"B";
  TradedOnMIAX:"B"
  ])

MASTERRENAME: ([
    Symbol: `sym;
    Security_Description: `description;
    CUSIP: `cusip;
    Security_Type: `securityType;
    SIP_Symbol: `SIPSymbol;
    Old_Symbol: `oldSym;
    Test_Symbol_Flag: `testFlag;
    Listed_Exchange: `ex;
    Tape: `tape;
    Unit_Of_Trade: `unit;
    Round_Lot: `roundLot;
    NYSE_Industry_Code: `NYSEIndustryCode;
    Shares_Outstanding: `sharesOutstanding;
    Halt_Delay_Reason: `haltDelayReason;
    Specialist_Clearing_Agent: `specialistClearingAgent;
    Specialist_Clearing_Number: `specialistClearingNumber;
    Specialist_Post_Number: `specialistPostNumber;
    Specialist_Panel: `specialistPanel;
    TradedOnNYSEMKT: `tradedOnNYSEMKT;
    TradedOnNASDAQBX: `tradedOnNASDAQBX;
    TradedOnNSX: `tradedOnNSX;
    TradedOnFINRA: `tradedOnFINRA;
    TradedOnISE: `tradedOnISE;
    TradedOnEdgeA: `tradedOnEdgeA;
    TradedOnEdgeX: `tradedOnEdgeX;
    TradedOnNYSETexas: `tradedOnNYSETexas;
    TradedOnNYSE: `tradedOnNYSE;
    TradedOnArca: `tradedOnArca;
    TradedOnNasdaq: `tradedOnNasdaq;
    TradedOnCBOE: `tradedOnCBOE;
    TradedOnPSX: `tradedOnPSX;
    TradedOnBATSY: `tradedOnBATSY;
    TradedOnBATS: `tradedOnBATS;
    TradedOnIEX: `tradedOnIEX;
    Tick_Pilot_Indicator: `tickPilotIndicator;
    Effective_Date: `effectiveDate;
    TradedOnLTSE: `tradedOnLTSE;
    TradedOnMEMX: `tradedOnMEMX;
    TradedOnMIAX: `tradedOnMIAX
  ])

/ Exchange ID to Exchange name mapping
EXNAMES: ([A: "NYSE American"; B: "NASDAQ OMX BX"; C: "NYSE National"; D: "FINRA Alternative Display Facility";
  I: "International Securities Exchange"; J: "Cboe EDGA Exchange"; K: "Cboe EDGX Exchange";
  L: "Long-Term Stock Exchange"; M: "Chicago Stock Exchange";
  N: "New York Stock Exchange"; P: "NYSE Arca"; S: "Consolidated Tape System"; T: "NASDAQ Stock Market";
  Q: "NASDAQ Stock Exchange"; V: "The Investors' Exchange"; W: "Chicago Broad Options Exchange";
  X: "NASDAQ OMX PSX"; Y: "Cboe BYX Exchange"; Z: "Cboe BZX Exchange"])

/ convert symbol keys to characters
EXNAMES: (raze string key EXNAMES)!value EXNAMES

/ Table trade: EQY_US_ALL_TRADE_*.csv
TRADESCHEMA: (!) . @[;0;`$] flip (
  ("Time";"N");
  ("Exchange";"C");
  ("Symbol";"*");
  ("Sale Condition";"S");
  ("Trade Volume";"E");
  ("Trade Price";"E");
  ("Trade Stop Stock Indicator";"S");
  ("Trade Correction Indicator";"H");
  ("Sequence Number";"I");
  ("Trade Id";"J");
  ("Source of Trade";"C");
  ("Trade Reporting Facility";"S");
  ("Participant Timestamp";"N");
  ("Trade Reporting Facility TRF Timestamp";"N");
  ("Trade Through Exempt Indicator";"B")
  )

TRADERENAME: (!) . @[;0;`$] flip (
  ("Time"; `time);
  ("Exchange"; `ex);
  ("Symbol"; `sym);
  ("Sale Condition"; `cond);
  ("Trade Volume"; `size);
  ("Trade Price"; `price);
  ("Trade Stop Stock Indicator"; `stop);
  ("Trade Correction Indicator"; `corr);
  ("Sequence Number"; `seq);
  ("Trade Id"; `tradeId);
  ("Source of Trade"; `source);
  ("Trade Reporting Facility"; `tradeReportingFacility);
  ("Participant Timestamp"; `participantTimestamp);
  ("Trade Reporting Facility TRF Timestamp"; `tradeReportingFacilityTRFTimestamp);
  ("Trade Through Exempt Indicator"; `tradeThroughExemptIndicator)
  )


/ Table quote: splits_us_all_bbo_*[0-9]_*.csv
QUOTESCHEMA: ([
  Time:"N";
  Exchange:"C";
  Symbol:"*";
  Bid_Price:"E";
  Bid_Size:"I";
  Offer_Price:"E";
  Offer_Size:"I";
  Quote_Condition:"C";
  Sequence_Number:"I";
  National_BBO_Ind:"C";
  FINRA_BBO_Indicator:"C";
  FINRA_ADF_MPID_Indicator:"C";
  Quote_Cancel_Correction:"C";
  Source_Of_Quote:"C";
  Retail_Interest_Indicator:"C";
  Short_Sale_Restriction_Indicator:"C";
  LULD_BBO_Indicator:"C";
  SIP_Generated_Message_Identifier:"C";
  National_BBO_LULD_Indicator:"C";
  Participant_Timestamp:"N";
  FINRA_ADF_Timestamp:"N";
  FINRA_ADF_Market_Participant_Quote_Indicator:"C";
  Security_Status_Indicator:"C"
  ])

QUOTERENAME: ([
  Time: `time;
  Exchange: `ex;
  Symbol: `sym;
  Bid_Price: `bid;
  Bid_Size: `bsize;
  Offer_Price: `ask;
  Offer_Size: `asize;
  Quote_Condition: `cond;
  Sequence_Number: `seq;
  National_BBO_Ind: `nationalBBOIndicator;
  FINRA_BBO_Indicator: `finraBBOIndicator;
  FINRA_ADF_MPID_Indicator: `finraADFMpidIndicator;
  Quote_Cancel_Correction: `corr;
  Source_Of_Quote: `source;
  Retail_Interest_Indicator: `retailInterestIndicator;
  Short_Sale_Restriction_Indicator: `shortSaleRestrictionIndicator;
  LULD_BBO_Indicator: `LULDBBOIndicator;
  SIP_Generated_Message_Identifier: `SIPGeneratedMessageIdentifier;
  National_BBO_LULD_Indicator: `nationalBBOLULDIndicator;
  Participant_Timestamp: `participantTimestamp;
  FINRA_ADF_Timestamp: `FINRAADFTimestamp;
  FINRA_ADF_Market_Participant_Quote_Indicator: `FINRAADFMarketParticipantQuoteIndicator;
  Security_Status_Indicator: `securityStatusIndicator
  ])