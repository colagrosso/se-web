CREATE TABLE `TocEntries` (
  `EbookId` int(10) unsigned NOT NULL,
  `TocEntry` text NOT NULL,
  KEY `index1` (`EbookId`),
  FULLTEXT `idxSearch` (`TocEntry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
