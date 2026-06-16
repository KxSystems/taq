master: ([]
    sym:`$();
    description:();
    cusip:`$();
    securityType:`$();
    SIPSymbol:`$();
    oldSym:`$();
    testFlag:`boolean$();
    ex:`char$();
    tape:`char$();
    unit:`short$();
    roundLot:`short$();
    NYSEIndustryCode:`$();
    sharesOutstanding:`float$();
    haltDelayReason:`char$();
    specialistClearingAgent:`$();
    specialistClearingNumber:`$();
    specialistPostNumber:`short$();
    specialistPanel:`char$();
    tradedOnNYSEMKT:`boolean$();
    tradedOnNASDAQBX:`boolean$();
    tradedOnNSX:`boolean$();
    tradedOnFINRA:`boolean$();
    tradedOnISE:`boolean$();
    tradedOnEdgeA:`boolean$();
    tradedOnEdgeX:`boolean$();
    tradedOnNYSETexas:`boolean$();
    tradedOnNYSE:`boolean$();
    tradedOnArca:`boolean$();
    tradedOnNasdaq:`boolean$();
    tradedOnCBOE:`boolean$();
    tradedOnPSX:`boolean$();
    tradedOnBATSY:`boolean$();
    tradedOnBATS:`boolean$();
    tradedOnIEX:`boolean$();
    tickPilotIndicator:`char$();
    effectiveDate: `date$();
    tradedOnLTSE:`boolean$();
    tradedOnMEMX:`boolean$();
    tradedOnMIAX:`boolean$());

trade:([]
    time:`timespan$();
    sym:`$();
    ex:`char$();
    cond:`$();
    size:`real$();
    price:`real$();
    stop:`$();
    corr:`short$();
    seq:`int$();
    tradeId:`long$();
    source:`char$();
    tradeReportingFacility:`$();
    participantTimestamp:`timespan$();
    tradeReportingFacilityTRFTimestamp:`timespan$();
    tradeThroughExemptIndicator:`boolean$());

quote:([]
    time:`timespan$();
    sym:`$();
    ex:`char$();
    bid:`real$();
    bsize:`int$();
    ask:`real$();
    asize:`int$();
    cond:`char$();
    seq:`int$();
    nationalBBOIndicator:`char$();
    finraBBOIndicator:`char$();
    finraADFMpidIndicator:`char$();
    corr:`char$();
    source:`char$();
    retailInterestIndicator:`char$();
    shortSaleRestrictionIndicator:`char$();
    LULDBBOIndicator:`char$();
    SIPGeneratedMessageIdentifier:`char$();
    nationalBBOLULDIndicator:`char$();
    participantTimestamp:`timespan$();
    FINRAADFTimestamp:`timespan$();
    FINRAADFMarketParticipantQuoteIndicator:`char$();
    securityStatusIndicator:`char$());

getSchemas: {[]
  :(master; trade; quote)
  };

export: ([getSchemas])