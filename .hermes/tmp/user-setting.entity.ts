import { Entity, Column, Index, PrimaryGeneratedColumn, UpdateDateColumn, ManyToOne, JoinColumn, Unique } from 'typeorm';
import { UserEntity } from './user.entity';

@Entity('user_settings')
@Unique('uk_user_key', ['user_token', 'setting_key'])
export class UserSettingEntity {
  @PrimaryGeneratedColumn({ type: 'int' })
  id: number;

  @Index('idx_user_token')
  @Column({ type: 'varchar', length: 64, name: 'user_token' })
  user_token: string;

  @Column({ type: 'varchar', length: 50, name: 'setting_key' })
  setting_key: string;

  @Column({ type: 'text', nullable: true, name: 'setting_value' })
  setting_value: string;

  @UpdateDateColumn({ type: 'timestamp', name: 'updated_at' })
  updated_at: Date;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_token', referencedColumnName: 'internal_token' })
  user: UserEntity;
}
