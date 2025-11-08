CREATE TABLE Fighter(
    Full_name VARCHAR(50),
    Nickname VARCHAR(50),
    Age INT NOT NULL,
    Country VARCHAR(50)  NOT NULL,
    PRIMARY KEY( Full_name, Nickname)
);


CREATE TABLE Weight_category(
    Category_Name VARCHAR(15) PRIMARY KEY ,
    Min_weight INT NOT NULL,
    Max_weight INT NOT NULL,
    CHECK(Min_weight < Max_weight)
);


CREATE TABLE Active(
    Full_name VARCHAR(50),
    Nickname VARCHAR(50),
    Category_name VARCHAR(15),
    Ranked INT,
    PRIMARY KEY (Full_name, Nickname, Category_name),
    UNIQUE (Full_name, Nickname),
--     UNIQUE (Ranked, Category_name),
    FOREIGN KEY (Full_name, Nickname) REFERENCES Fighter ON DELETE CASCADE,
    FOREIGN KEY (Category_name) REFERENCES Weight_category ON DELETE CASCADE
);

CREATE TABLE Retired(
    Full_name VARCHAR(50),
    Nickname VARCHAR(50),
    Hall_of_fame BIT NOT NULL,
    Goat BIT NOT NULL,
    PRIMARY KEY (Full_name, Nickname),
    FOREIGN KEY (Full_name, Nickname) REFERENCES Fighter ON DELETE CASCADE,
    CHECK ((Hall_of_fame = 0 AND Goat = 0) OR  (Hall_of_fame = 1 And Goat = 0) OR (Hall_of_fame = 1 And Goat = 1))
);

CREATE TABLE Event(
    Date Date PRIMARY KEY,
    Venue Varchar(50) NOT NULL ,
    Block_buster BIT NOT NULL,
);


CREATE TABLE Fight(
    Date Date ,
    Category_Name VARCHAR(15) ,
    Place_in_queue INT,
    PRIMARY KEY (Date, Category_Name, Place_in_queue),
    FOREIGN KEY (Date) REFERENCES Event ON DELETE CASCADE ,
    FOREIGN KEY (Category_Name) REFERENCES Weight_category ON DELETE CASCADE,

)


CREATE TABLE Fights_against(
    Full_name1 VARCHAR(50) NOT NULL,
    Nickname1 VARCHAR(50) NOT NULL,
    Category_name1 VARCHAR(15) NOT NULL,
    Full_name2 VARCHAR(50) NOT NULL,
    Nickname2 VARCHAR(50) NOT NULL,
    Category_name2 VARCHAR(15) NOT NULL,
    Date DATE NOT NULL,
    Category_of_weight VARCHAR(15) NOT NULL,
    Place_in_queue INT NOT NULL,
    FOREIGN KEY(Full_name1, Nickname1, Category_name1) REFERENCES  Active(Full_name, Nickname, Category_name), --ON DELETE CASCADE ,
    FOREIGN KEY(Full_name2, Nickname2, Category_name2) REFERENCES  Active(Full_name, Nickname, Category_name), --ON DELETE CASCADE ,
    FOREIGN KEY (Date, Category_of_weight, Place_in_queue) REFERENCES  Fight(Date, Category_Name, Place_in_queue) ON DELETE CASCADE,
    CHECK (Category_name1 = Category_name2 AND Category_name2 = Category_of_weight),
    CHECK (Full_name1 != Full_name2 OR Nickname1 != Nickname2),
    UNIQUE (Date, Place_in_queue)
);


CREATE TABLE Championship_fight(
    Date Date,
    Category_Name VARCHAR(15) ,
    Place_in_queue INT,
    Money_generated INT NOT NULL ,
    Amount_Of_views INT NOT NULL ,
    PRIMARY KEY (Date, Category_Name, Place_in_queue),
    FOREIGN KEY (Date, Category_Name, Place_in_queue) REFERENCES Fight ON DELETE CASCADE ,
);

CREATE TABLE Championship_winner(
    Date Date,
    Category_name_fight VARCHAR(15) ,
    Place_in_queue INT,
    Full_name VARCHAR(50),
    Nickname VARCHAR(50),
    Category_name_fighter VARCHAR(15),
    FOREIGN KEY (Date, Category_name_fight, Place_in_queue) REFERENCES Championship_fight(Date, Category_Name, Place_in_queue), -- ON DELETE CASCADE,
    FOREIGN KEY (Full_name, Nickname, Category_name_fighter) REFERENCES Active(full_name, nickname, category_name)  ON DELETE CASCADE,
    CHECK (Category_name_fight = Category_name_fighter),
    unique (Date,Place_in_queue)
);


Create TABLE Invited(
    Date Date,
    Full_name VARCHAR(50),
    Nickname VARCHAR(50),
    FOREIGN KEY (Date) REFERENCES Event ON DELETE CASCADE,
    FOREIGN KEY (Full_name, Nickname) REFERENCES Retired ON DELETE CASCADE,
    UNIQUE (Date)
);

CREATE TABLE Retired_and_invited(
    Date Date ,
    Full_name VARCHAR(50),
    Nickname VARCHAR(50),
    PRIMARY KEY (Date, Full_name, Nickname),
    FOREIGN KEY (Date) REFERENCES Event ON DELETE CASCADE ,
    FOREIGN KEY (Full_name, Nickname) REFERENCES Retired ON DELETE CASCADE
    --צריך להיות כאן FK ל- PROMOTED שלא ניתן לעשותו מפני שיוצר מעגליות
)

CREATE TABLE Social_network(
    Name VARCHAR(50) PRIMARY KEY ,
    Amount_of_fans INT
);

CREATE Table Promoted(
    Name VARCHAR(50),
    Date Date,
    Full_name VARCHAR(50),
    Nickname VARCHAR(50),
    PRIMARY KEY (Name, Date, Full_name,Nickname),
    FOREIGN KEY (Name) REFERENCES Social_network ON DELETE CASCADE ,
    FOREIGN KEY (Date,Full_name, Nickname) REFERENCES Retired_and_invited ON DELETE CASCADE
)

CREATE TABLE Sponsors(
    Name VARCHAR(50),
    Serial_Number INT,
    Date_of_beginning Date,
    Amount INT,
    PRIMARY KEY (Name, Serial_Number)
)

CREATE TABLE Sponsored_by(
    Name VARCHAR(50),
    Serial_Number INT,
    Date Date,
    PRIMARY KEY (Name, Serial_Number, Date),
    FOREIGN KEY (Name,Serial_Number) REFERENCES Sponsors ON DELETE CASCADE,
    FOREIGN KEY (Date) REFERENCES Event ON DELETE CASCADE
)

CREATE TABLE Broadcasting_channels(
    Name VARCHAR(50) PRIMARY KEY,
    Location VARCHAR(50),
    Amount_of_viewers INT,
)

CREATE TABLE Broadcasted_by(
    Name VARCHAR(50),
    Date DATE,
    PRIMARY KEY (Name,Date),
    FOREIGN KEY (Name) REFERENCES Broadcasting_Channels ON DELETE CASCADE,
    FOREIGN KEY (Date) REFERENCES Event ON DELETE CASCADE
)

CREATE TABLE Broadcasters(
    Name VARCHAR(50),
    Age INT,
    Salary INT,
    Works_at VARCHAR(50),
    FOREIGN KEY (Works_At) REFERENCES Broadcasting_channels(Name) ON DELETE CASCADE,
    PRIMARY KEY (Name, Works_at)
)

CREATE TABLE Favorite_fighter(
    Name VARCHAR(50),
    Works_at VARCHAR(50),
    Full_name VARCHAR(50),
    Nickname VARCHAR(50),
    FOREIGN KEY (Name, Works_at) REFERENCES Broadcasters ON DELETE CASCADE,
    FOREIGN KEY (Full_name, Nickname) REFERENCES Fighter ON DELETE CASCADE
)